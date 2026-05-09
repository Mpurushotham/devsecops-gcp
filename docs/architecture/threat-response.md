# Threat Response Architecture

## Overview

Automated threat response is built on a pipeline: Security Command Center (SCC) or Falco detects an event → Pub/Sub routes it → Cloud Functions v2 classifies and responds. Human escalation happens via Slack and PagerDuty for findings that require judgment.

---

## Response Pipeline

```
┌─────────────────────┐     ┌──────────┐     ┌────────────────────┐
│  Security Command   │────▶│  Pub/Sub │────▶│  Cloud Functions   │
│  Center (SCC)       │     │  Topic   │     │  scc-auto-response │
└─────────────────────┘     └──────────┘     └────────────────────┘
                                  │                     │
┌─────────────────────┐           │           ┌─────────▼──────────┐
│  Falco              │───────────┘           │  Slack / PagerDuty │
│  (via Falcosidekick)│                       │  notification      │
└─────────────────────┘                       └────────────────────┘
                                                         │
                                              ┌──────────▼─────────┐
                                              │  Cloud Logging      │
                                              │  audit entry        │
                                              └────────────────────┘
```

All automated actions are logged to Cloud Logging with the log name `scc-auto-response`. Every action includes: finding category, resource, action taken, dry_run status, and timestamp.

---

## Automated Response Handlers

The Cloud Function at `cloud-functions/scc-auto-response/main.py` dispatches on `finding.category`:

| SCC Finding | Automated Action | Risk Level |
|---|---|---|
| `PUBLIC_BUCKET_ACL` | Remove `allUsers` / `allAuthenticatedUsers` via Storage API | LOW — safe to auto-remediate |
| `OPEN_FIREWALL` | Insert priority-900 deny rule via Compute API | LOW — safe to auto-remediate |
| `SERVICE_ACCOUNT_KEY_CREATED` | Alert only (key already exists — revocation requires investigation) | MEDIUM |
| `ANOMALOUS_IAM_GRANT` | Alert only — human must review before revoking | MEDIUM |
| `CRYPTO_MINER_DETECTED` | Stop VM instance, snapshot disk for forensics | HIGH |
| `EXFILTRATION` | Revoke SA token, page on-call, flag for VPC-SC emergency isolation | CRITICAL |

### DRY_RUN Mode

The Cloud Function respects the `DRY_RUN` environment variable (set in `terraform/modules/scc-response/cloud_functions.tf`). When `DRY_RUN=true`:
- All GCP API calls are skipped
- The function logs what action *would* have been taken
- Slack notifications are still sent so the team can observe without impact

Switch to `DRY_RUN=false` only after validating the function behavior in staging.

---

## SCC Notification Configuration

Two notification configs are active (defined in `terraform/modules/org-foundation/scc.tf`):

| Config | Filter | Topic |
|---|---|---|
| `all-findings` | `` (empty — all findings) | `scc-findings` |
| `critical-high-findings` | `severity="CRITICAL" OR severity="HIGH"` | `scc-findings` |

A mute config `dev-low-severity` suppresses LOW/MEDIUM findings in dev projects to reduce noise.

---

## Dead Letter Queue

If the Cloud Function fails to process a message (exception, timeout), the message goes to the DLQ topic `scc-dlq` after 5 retries. Operations team must monitor this topic:

```bash
# Pull messages from DLQ to inspect failures
gcloud pubsub subscriptions pull scc-dlq-sub \
  --project=PROJECT_ID \
  --max-messages=10 \
  --auto-ack
```

An alert policy should be configured on the DLQ subscription's `subscription/num_undelivered_messages` metric.

---

## Falco Response Flow

Falco detects kernel-level events on GKE nodes and routes to Pub/Sub via Falcosidekick:

```
Kernel syscall
  → Falco eBPF probe (DaemonSet on every node)
  → Rule match → Falcosidekick
  → Pub/Sub topic: falco-alerts
  → [Future] Cloud Function or manual response
```

### Falco Severity Mapping

| Falco Priority | Response |
|---|---|
| DEBUG, INFO | Log only |
| NOTICE, WARNING | Slack notification |
| ERROR | Slack + PagerDuty (business hours) |
| CRITICAL | Slack + PagerDuty (24/7 on-call) |

Current Falco configuration (`kubernetes/falco/values.yaml`) routes all events at WARNING priority or above to Pub/Sub. Falcosidekick handles the Pub/Sub publish using Workload Identity (no key files).

---

## IAM Drift Remediation

The `cloud-functions/iam-drift-remediation/main.py` function scans for:
- Primitive roles (`roles/owner`, `roles/editor`, `roles/viewer`) bound on projects
- External members (`allUsers`, `allAuthenticatedUsers`) in any IAM binding
- Non-domain user accounts added to project IAM

This function is designed to run on a Cloud Scheduler schedule (daily). Violations are logged and Slack-notified but not auto-remediated (primitive role revocation requires human judgment about which replacement role to assign).

---

## Manual Response Procedures

### Compromised Service Account

```bash
# 1. Revoke all keys
gcloud iam service-accounts keys list \
  --iam-account=SA_EMAIL --project=PROJECT_ID

gcloud iam service-accounts keys delete KEY_ID \
  --iam-account=SA_EMAIL --project=PROJECT_ID

# 2. Disable SA (blocks all authentication)
gcloud iam service-accounts disable SA_EMAIL --project=PROJECT_ID

# 3. Find recent API calls from this SA
gcloud logging read \
  'protoPayload.authenticationInfo.principalEmail="SA_EMAIL"' \
  --project=PROJECT_ID --freshness=24h --format=json | \
  jq '.[] | {time: .timestamp, method: .protoPayload.methodName, resource: .resource.labels}'
```

### Compromised GKE Workload

```bash
# 1. Cordon the node to prevent new pod scheduling
kubectl cordon NODE_NAME

# 2. Capture state before killing (forensics)
kubectl get pod POD_NAME -n NAMESPACE -o yaml > /tmp/pod-forensics.yaml

# 3. Kill the pod
kubectl delete pod POD_NAME -n NAMESPACE --grace-period=0

# 4. If node is compromised: drain then delete
kubectl drain NODE_NAME --ignore-daemonsets --delete-emptydir-data
gcloud container nodes delete NODE_NAME --cluster=CLUSTER --zone=ZONE --project=PROJECT_ID

# 5. Review Falco events for the pod
gcloud logging read \
  'jsonPayload.k8s.pod_name="POD_NAME"' \
  --project=PROJECT_ID --freshness=1h --format=json
```

### Emergency VPC-SC Isolation

If an exfiltration event occurs and VPC-SC is in DRY_RUN for the affected environment, escalate to ENFORCE immediately:

1. Update `vpc_sc_mode = "ENFORCE"` in the environment's `terraform.tfvars`
2. Run `terraform apply` in the affected environment (use emergency break-glass SA if CI is unavailable)
3. Verify all legitimate access resumes (check Cloud Logging for new VPC-SC violations)
4. Do not revert to DRY_RUN until the incident is fully contained

### Public GCS Bucket (Manual)

```bash
# Remove public access
gsutil iam ch -d allUsers gs://BUCKET_NAME
gsutil iam ch -d allAuthenticatedUsers gs://BUCKET_NAME

# Verify
gsutil iam get gs://BUCKET_NAME
```

---

## Alert Routing

| Severity | Channel | Response Time |
|---|---|---|
| CRITICAL | PagerDuty + Slack #security-incidents | 15 minutes |
| HIGH | Slack #security-alerts + email | 1 hour |
| MEDIUM | Slack #security-alerts | 4 hours (business hours) |
| LOW | Cloud Logging only | Next business day review |

---

## Post-Incident

1. **Preserve evidence**: Cloud Logging exports are retained 7 years in GCS (LOCKED). Do not attempt to delete audit logs.
2. **Root cause analysis**: Document in a post-mortem within 48 hours.
3. **Update automation**: If the incident type was not covered by automated response, add a handler to `cloud-functions/scc-auto-response/main.py` and a corresponding test in `test_main.py`.
4. **Update Falco rules**: If the attack pattern was not detected, add a rule in `kubernetes/falco/custom-rules/`.

---

## Related

- SCC response function: `cloud-functions/scc-auto-response/main.py`
- IAM drift function: `cloud-functions/iam-drift-remediation/main.py`
- Falco custom rules: `kubernetes/falco/custom-rules/`
- Pub/Sub / Functions Terraform: `terraform/modules/scc-response/`
- Incident response runbook: `docs/runbooks/incident-response.md`
- Security model: `docs/architecture/security-model.md`
