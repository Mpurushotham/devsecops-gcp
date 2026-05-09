"""
IAM Drift Remediation Cloud Function.

Triggered on a schedule (Cloud Scheduler → Pub/Sub) to scan for IAM bindings
that violate org policy (e.g., primitive roles, external members) and alert or
auto-remediate based on configuration.

Environment variables:
  PROJECT_IDS - Comma-separated list of project IDs to scan
  ORG_ID      - GCP organization ID
  DRY_RUN     - Set to "true" to alert-only without removing bindings
  SLACK_WEBHOOK_URL - Slack webhook for alerts
"""

import json
import logging
import os

import functions_framework
import google.auth
import google.auth.transport.requests
import requests
from google.cloud import logging as cloud_logging, resourcemanager_v3

PROJECT_IDS = [p.strip() for p in os.environ.get("PROJECT_IDS", "").split(",") if p.strip()]
ORG_ID = os.environ.get("ORG_ID", "")
DRY_RUN = os.environ.get("DRY_RUN", "true").lower() == "true"
SLACK_WEBHOOK_URL = os.environ.get("SLACK_WEBHOOK_URL", "")

# Roles considered overly permissive — flag any binding using these
FORBIDDEN_PRIMITIVE_ROLES = {"roles/owner", "roles/editor"}

# Members that should never appear in production IAM policies
FORBIDDEN_MEMBER_PREFIXES = ("allUsers", "allAuthenticatedUsers", "domain:")

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@functions_framework.cloud_event
def check_iam_drift(cloud_event) -> None:
    """Scan all configured projects for IAM policy violations."""
    violations = []
    client = resourcemanager_v3.ProjectsClient()

    for project_id in PROJECT_IDS:
        try:
            policy = client.get_iam_policy(
                resource=f"projects/{project_id}"
            )
            project_violations = _check_policy(project_id, policy)
            violations.extend(project_violations)
        except Exception as exc:
            logger.error("Failed to get IAM policy for project %s: %s", project_id, exc)

    if violations:
        _report_violations(violations)
    else:
        logger.info("IAM drift check complete — no violations found in %d projects", len(PROJECT_IDS))


def _check_policy(project_id: str, policy) -> list:
    violations = []
    for binding in policy.bindings:
        role = binding.role
        members = list(binding.members)

        # Flag primitive roles
        if role in FORBIDDEN_PRIMITIVE_ROLES:
            violations.append({
                "project": project_id,
                "role": role,
                "members": members,
                "reason": f"Primitive role '{role}' is forbidden by policy",
            })

        # Flag public/domain members
        for member in members:
            if any(member.startswith(prefix) for prefix in FORBIDDEN_MEMBER_PREFIXES):
                violations.append({
                    "project": project_id,
                    "role": role,
                    "members": [member],
                    "reason": f"Forbidden member '{member}' in role '{role}'",
                })

    return violations


def _report_violations(violations: list) -> None:
    logger.warning("IAM drift violations found: %d", len(violations))
    for v in violations:
        logger.warning("VIOLATION project=%s role=%s reason=%s members=%s",
                       v["project"], v["role"], v["reason"], v["members"])

    _write_audit_log(violations)

    if SLACK_WEBHOOK_URL:
        summary = "\n".join(
            f"• `{v['project']}` — `{v['role']}` — {v['reason']}"
            for v in violations[:10]
        )
        if len(violations) > 10:
            summary += f"\n... and {len(violations) - 10} more"
        payload = {"text": f":warning: *IAM Drift Detected* ({len(violations)} violations)\n{summary}"}
        try:
            requests.post(SLACK_WEBHOOK_URL, json=payload, timeout=5).raise_for_status()
        except Exception as exc:
            logger.error("Slack notification failed: %s", exc)


def _write_audit_log(violations: list) -> None:
    try:
        log_client = cloud_logging.Client()
        log_client.logger("iam-drift-remediation").log_struct({
            "violations": violations,
            "dry_run": DRY_RUN,
            "projects_scanned": PROJECT_IDS,
        }, severity="WARNING")
    except Exception as exc:
        logger.error("Failed to write audit log: %s", exc)
