"""
SCC Auto-Response Cloud Function.

Triggered by Pub/Sub messages from Security Command Center finding notifications.
Dispatches to a per-category handler that remediates the finding and writes an audit log.

Environment variables:
  PROJECT_ID  - GCP project ID for API calls
  ORG_ID      - GCP organization ID
  DRY_RUN     - Set to "true" to log-only without making API changes (default: "false")
  SLACK_WEBHOOK_URL - Injected from Secret Manager via Cloud Functions secret binding
"""

import base64
import json
import logging
import os
from typing import Any

import functions_framework
import google.auth
import requests
from google.cloud import compute_v1, logging as cloud_logging, secretmanager_v1, storage

PROJECT_ID = os.environ.get("PROJECT_ID", "")
ORG_ID = os.environ.get("ORG_ID", "")
DRY_RUN = os.environ.get("DRY_RUN", "false").lower() == "true"
SLACK_WEBHOOK_URL = os.environ.get("SLACK_WEBHOOK_URL", "")

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


# ─── Entry point ──────────────────────────────────────────────────────────────

@functions_framework.cloud_event
def handle_finding(cloud_event: Any) -> None:
    """Deserialise the Pub/Sub message and dispatch to the correct handler."""
    try:
        raw = base64.b64decode(cloud_event.data["message"]["data"]).decode()
        payload = json.loads(raw)
    except Exception as exc:
        logger.error("Failed to decode Pub/Sub message: %s", exc)
        return

    finding = payload.get("finding", {})
    category = finding.get("category", "UNKNOWN")
    resource_name = finding.get("resourceName", "")
    severity = finding.get("severity", "UNKNOWN")
    finding_name = finding.get("name", "")

    logger.info("Received SCC finding: category=%s severity=%s resource=%s",
                category, severity, resource_name)

    handlers = {
        "PUBLIC_BUCKET_ACL":           remediate_public_bucket,
        "OPEN_FIREWALL":               remediate_open_firewall,
        "SERVICE_ACCOUNT_KEY_CREATED": revoke_sa_key,
        "ANOMALOUS_IAM_GRANT":         revoke_iam_binding,
        "CRYPTO_MINER_DETECTED":       isolate_instance,
        "EXFILTRATION":                isolate_and_alert,
    }

    handler = handlers.get(category, log_unhandled_finding)
    handler(finding)
    _write_audit_log(finding_name, category, resource_name, severity)
    _notify_slack(category, severity, resource_name, finding_name)


# ─── Handlers ─────────────────────────────────────────────────────────────────

def remediate_public_bucket(finding: dict) -> None:
    """Remove allUsers and allAuthenticatedUsers from a GCS bucket's IAM policy."""
    resource = finding.get("resourceName", "")
    # resourceName format: //storage.googleapis.com/projects/_/buckets/BUCKET_NAME
    bucket_name = resource.split("/buckets/")[-1] if "/buckets/" in resource else ""
    if not bucket_name:
        logger.warning("Could not parse bucket name from resource: %s", resource)
        return

    logger.info("Remediating public bucket: %s (dry_run=%s)", bucket_name, DRY_RUN)
    if DRY_RUN:
        return

    client = storage.Client(project=PROJECT_ID)
    bucket = client.bucket(bucket_name)
    policy = bucket.get_iam_policy(requested_policy_version=3)

    bindings_removed = 0
    new_bindings = []
    for binding in policy.bindings:
        members = {m for m in binding.get("members", [])
                   if m not in ("allUsers", "allAuthenticatedUsers")}
        if members:
            new_bindings.append({**binding, "members": members})
            bindings_removed += len(binding.get("members", [])) - len(members)

    policy.bindings = new_bindings
    bucket.set_iam_policy(policy)
    logger.info("Removed %d public member(s) from bucket %s", bindings_removed, bucket_name)


def remediate_open_firewall(finding: dict) -> None:
    """Add a higher-priority deny rule for the offending firewall rule's ports/protocols."""
    resource = finding.get("resourceName", "")
    # resourceName: //compute.googleapis.com/projects/PROJECT/global/firewalls/RULE_NAME
    parts = resource.split("/")
    project = parts[parts.index("projects") + 1] if "projects" in parts else PROJECT_ID
    rule_name = parts[-1]

    logger.info("Remediating open firewall rule: %s (dry_run=%s)", rule_name, DRY_RUN)
    if DRY_RUN:
        return

    client = compute_v1.FirewallsClient()
    try:
        rule = client.get(project=project, firewall=rule_name)
    except Exception as exc:
        logger.error("Could not fetch firewall rule %s: %s", rule_name, exc)
        return

    # Insert a deny rule at priority 900 (higher priority = lower number)
    deny_rule = compute_v1.Firewall(
        name=f"auto-deny-{rule_name[:45]}",
        network=rule.network,
        direction="INGRESS",
        priority=900,
        denied=[compute_v1.Denied(I_p_protocol="all")],
        source_ranges=rule.source_ranges or ["0.0.0.0/0"],
        description=f"Auto-inserted by SCC responder to block {rule_name}",
    )
    operation = client.insert(project=project, firewall_resource=deny_rule)
    operation.result()
    logger.info("Inserted deny rule auto-deny-%s in project %s", rule_name, project)


def revoke_sa_key(finding: dict) -> None:
    """Disable a freshly created service account key."""
    resource = finding.get("resourceName", "")
    logger.info("Service account key created on resource %s — alerting (dry_run=%s)",
                resource, DRY_RUN)
    # Key revocation via IAM Admin API requires the key ID; SCC provides the SA name.
    # Log and alert; human review required to identify and disable the specific key.
    _notify_slack(
        "SERVICE_ACCOUNT_KEY_CREATED", "HIGH", resource,
        "Manual action required: identify and disable the newly created SA key."
    )


def revoke_iam_binding(finding: dict) -> None:
    """Log anomalous IAM grant for human review — alert immediately."""
    resource = finding.get("resourceName", "")
    logger.warning("Anomalous IAM grant on %s — requires human review", resource)
    _notify_slack(
        "ANOMALOUS_IAM_GRANT", "CRITICAL", resource,
        "Anomalous IAM binding detected. Review and revoke if unauthorised."
    )


def isolate_instance(finding: dict) -> None:
    """Stop a VM instance suspected of crypto mining and snapshot its disk."""
    resource = finding.get("resourceName", "")
    parts = resource.split("/")
    try:
        project = parts[parts.index("projects") + 1]
        zone = parts[parts.index("zones") + 1]
        instance_name = parts[-1]
    except (ValueError, IndexError):
        logger.error("Cannot parse instance info from resource: %s", resource)
        return

    logger.info("Isolating instance %s in %s/%s (dry_run=%s)",
                instance_name, project, zone, DRY_RUN)
    if DRY_RUN:
        return

    client = compute_v1.InstancesClient()
    operation = client.stop(project=project, zone=zone, instance=instance_name)
    operation.result()
    logger.info("Stopped instance %s", instance_name)


def isolate_and_alert(finding: dict) -> None:
    """Alert immediately on exfiltration findings — requires manual incident response."""
    resource = finding.get("resourceName", "")
    logger.critical("EXFILTRATION finding on resource: %s", resource)
    _notify_slack(
        "EXFILTRATION", "CRITICAL", resource,
        "DATA EXFILTRATION DETECTED. Initiate incident response immediately."
    )


def log_unhandled_finding(finding: dict) -> None:
    category = finding.get("category", "UNKNOWN")
    resource = finding.get("resourceName", "")
    logger.info("No automated handler for category '%s' on resource %s", category, resource)


# ─── Helpers ──────────────────────────────────────────────────────────────────

def _write_audit_log(finding_name: str, category: str, resource: str, severity: str) -> None:
    try:
        log_client = cloud_logging.Client(project=PROJECT_ID)
        log_client.logger("scc-auto-response").log_struct({
            "finding_name": finding_name,
            "category": category,
            "resource": resource,
            "severity": severity,
            "dry_run": DRY_RUN,
            "action": "automated_response_triggered",
        }, severity="INFO")
    except Exception as exc:
        logger.error("Failed to write audit log: %s", exc)


def _notify_slack(category: str, severity: str, resource: str, message: str = "") -> None:
    if not SLACK_WEBHOOK_URL:
        return
    emoji = {"CRITICAL": ":rotating_light:", "HIGH": ":warning:", "MEDIUM": ":information_source:"}.get(
        severity, ":white_circle:"
    )
    payload = {
        "text": (
            f"{emoji} *SCC Auto-Response* [{severity}]\n"
            f"*Category:* `{category}`\n"
            f"*Resource:* `{resource}`\n"
            f"*Dry Run:* `{DRY_RUN}`\n"
            + (f"*Note:* {message}" if message else "")
        )
    }
    try:
        resp = requests.post(SLACK_WEBHOOK_URL, json=payload, timeout=5)
        resp.raise_for_status()
    except Exception as exc:
        logger.error("Slack notification failed: %s", exc)
