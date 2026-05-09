# Incident Response Runbook

## SCC Finding Response

### Automated (via Cloud Function)

These finding categories are handled automatically by `cloud-functions/scc-auto-response/`:

| Category | Action |
|---|---|
| `PUBLIC_BUCKET_ACL` | Removes allUsers/allAuthenticatedUsers from bucket IAM |
| `OPEN_FIREWALL` | Inserts a priority-900 deny-all rule above the offending rule |
| `SERVICE_ACCOUNT_KEY_CREATED` | Alerts Slack — human must identify and disable the key |
| `ANOMALOUS_IAM_GRANT` | Alerts Slack — human must review and revoke |
| `CRYPTO_MINER_DETECTED` | Stops the VM instance |
| `EXFILTRATION` | Pages on-call immediately |

To put the function in DRY_RUN mode (alert-only, no API changes):
```bash
gcloud functions deploy scc-auto-responder \
  --update-env-vars DRY_RUN=true \
  --project=SECURITY_PROJECT_ID \
  --region=us-central1
```

### Manual Response Checklist

1. **Acknowledge** the finding in SCC console
2. **Investigate** using the resource name and audit logs in BigQuery:
   ```sql
   SELECT timestamp, protoPayload.authenticationInfo.principalEmail, protoPayload.methodName
   FROM `LOGGING_PROJECT.audit_logs.cloudaudit_googleapis_com_activity_*`
   WHERE resource.labels.project_id = 'AFFECTED_PROJECT'
   AND timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
   ORDER BY timestamp DESC
   ```
3. **Contain** — revoke credentials, isolate resource, add deny firewall rule
4. **Eradicate** — remediate root cause, rotate affected secrets
5. **Recover** — restore from known-good state, re-apply Terraform if needed
6. **Post-incident** — document in the SCC finding notes, update runbook

## Falco Alert Response

Falco alerts route to Pub/Sub topic `falco-alerts` and then to Slack via Falcosidekick.

For `CRITICAL` severity alerts:
```bash
# Identify the affected pod
kubectl get pod -A | grep <container_name>

# Capture forensic info before killing
kubectl describe pod <pod_name> -n <namespace> > /tmp/pod-forensics.txt
kubectl logs <pod_name> -n <namespace> --previous > /tmp/pod-logs.txt

# Kill the pod immediately
kubectl delete pod <pod_name> -n <namespace>

# If the image is compromised, update allowed-repos Gatekeeper constraint
# to block the offending image prefix
```

## Compromised Service Account Key

```bash
# List keys for the SA
gcloud iam service-accounts keys list \
  --iam-account=SA_EMAIL \
  --project=PROJECT_ID

# Disable the suspicious key (do not delete yet — preserve for forensics)
gcloud iam service-accounts keys disable KEY_ID \
  --iam-account=SA_EMAIL \
  --project=PROJECT_ID

# After 48h with no impact, delete
gcloud iam service-accounts keys delete KEY_ID \
  --iam-account=SA_EMAIL \
  --project=PROJECT_ID
```

## GKE Cluster Compromise

```bash
# Immediately revoke the cluster credentials from the attacker
# Rotate the cluster's master authorized networks to remove any unauthorized CIDR
gcloud container clusters update CLUSTER_NAME \
  --region=REGION \
  --master-authorized-networks=TRUSTED_CIDR \
  --project=PROJECT_ID

# Rotate cluster credentials
gcloud container clusters update CLUSTER_NAME \
  --region=REGION \
  --start-credential-rotation \
  --project=PROJECT_ID
```
