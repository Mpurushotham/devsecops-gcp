# CIS GCP Benchmark 2.0 — Control Mapping

## Section 1: Identity and Access Management

| CIS ID | Control | Implementation |
|---|---|---|
| 1.1 | Ensure service account has no admin privileges | `org_policies.tf`: `iam.disableServiceAccountKeyCreation`; `deny_external_iam.rego` blocks primitive roles |
| 1.2 | Ensure service account does not have admin privileges | Prowler check `gcp_iam_no_service_account_admin_privileges` in CI |
| 1.4 | Ensure primitive roles are not used | `deny_external_iam.rego`; Prowler daily scan |
| 1.5 | Ensure no service account has service account key | `org_policies.tf`: `iam.disableServiceAccountKeyCreation` = enforce |
| 1.6 | Ensure user-managed/external SA keys are rotated every 90 days | KMS key rotation set to 90 days; Prowler check |
| 1.7 | Ensure SA keys are not created at project level | Org policy enforced |
| 1.9 | Ensure KMS keys are not anonymously accessible | Prowler + `deny_external_iam.rego` |
| 1.11 | Ensure OSLogin is enabled for VM instances | `require_os_login.rego`; org policy `compute.requireOsLogin` |
| 1.12 | Ensure API keys are restricted to only APIs needed | Prowler check `gcp_apikeys_key_exists` |

## Section 2: Logging and Monitoring

| CIS ID | Control | Implementation |
|---|---|---|
| 2.1 | Ensure Cloud Audit Logging is configured properly | `audit_logs.tf`: DATA_READ/WRITE/ADMIN_READ for all services |
| 2.2 | Ensure sink is configured for all log entries | `audit_logs.tf`: org-level sink to BigQuery + GCS |
| 2.3 | Ensure log retention is >= 365 days | GCS archive bucket: 7-year retention with lock |
| 2.4 | Ensure log metric filter for project IAM changes | `alert_policies.tf`: `anomalous_iam_grant` alert |
| 2.5 | Ensure log metric filter for audit config changes | `alert_policies.tf`: `org_policy_changed` alert |
| 2.6 | Ensure log metric filter for custom role changes | Prowler daily |
| 2.7 | Ensure log metric filter for VPC network changes | `alert_policies.tf`: `firewall_modified` alert |
| 2.8 | Ensure log metric filter for VPC firewall rule changes | `alert_policies.tf`: `firewall_modified` alert |
| 2.9 | Ensure log metric filter for VPC route changes | Prowler daily |
| 2.10 | Ensure log metric filter for GCS IAM permission changes | Prowler daily |
| 2.11 | Ensure log metric filter for SQL instance changes | Prowler daily |
| 2.12 | Ensure log metric filter for Cloud Storage changes | Prowler daily |
| 2.15 | Ensure VPC Flow Logs are enabled | `require_vpc_flow_logs.rego`; `subnets.tf`: flow_sampling=1.0 |

## Section 3: Networking

| CIS ID | Control | Implementation |
|---|---|---|
| 3.1 | Ensure the default network is not created | `project-factory/apis.tf`: delete default network on creation |
| 3.2 | Ensure legacy networks are not created | Org policy: `compute.skipDefaultNetworkCreation` |
| 3.3 | Ensure no HTTPS or SSL proxy LB has SSL policy with weak ciphers | Prowler check |
| 3.6 | Ensure SSH access is restricted from internet | `firewall.tf`: deny-all-ingress base + IAP-only SSH |
| 3.7 | Ensure RDP access is restricted from internet | `firewall.tf`: deny-all-ingress base |
| 3.8 | Ensure VPC Flow Logs are enabled for every subnet | `subnets.tf` + `require_vpc_flow_logs.rego` |
| 3.9 | Ensure no open ingress firewall rules to TCP port 22 | `firewall.tf` default deny + Prowler check |
| 3.10 | Ensure firewall rule logging is enabled | `firewall.tf`: all rules have `log_config` |

## Section 4: Virtual Machines

| CIS ID | Control | Implementation |
|---|---|---|
| 4.1 | Ensure instances are not configured with default service account | `workload_identity.tf`: custom minimal node SA |
| 4.2 | Ensure instances are not configured to use default SA with full scope | Node SA has only required roles (logging, monitoring, artifact registry) |
| 4.3 | Ensure that confidential computing is enabled | (Optional enhancement — add to GKE node config) |
| 4.4 | Ensure OS Login is enabled | `require_os_login.rego`; org policy enforced |
| 4.6 | Ensure Compute instances do not have public IPs | `deny_public_ip.rego`; org policy `compute.vmExternalIpAccess` deny all |
| 4.7 | Ensure Compute instances are not publicly accessible via RDP | `firewall.tf` deny all ingress |
| 4.11 | Ensure Shielded VM is enabled | `node_pools.tf`: `enable_secure_boot=true`, `enable_integrity_monitoring=true` |

## Section 5: Storage

| CIS ID | Control | Implementation |
|---|---|---|
| 5.1 | Ensure Cloud Storage buckets are not anonymously accessible | Org policy: `storage.publicAccessPrevention=enforced` |
| 5.2 | Ensure Cloud Storage buckets use CMEK | `require_cmek.rego`; `kms.tf` creates keys; all buckets reference them |
| 5.3 | Ensure VPC Flow Log buckets are not publicly accessible | Org policy + `log_sinks.tf`: `public_access_prevention=enforced` |
| 5.4 | Ensure uniform bucket-level access is enabled | Org policy: `storage.uniformBucketLevelAccess=enforce` |

## Section 6: Kubernetes Engine (GKE)

| CIS ID | Control | Implementation |
|---|---|---|
| 6.1 | Ensure Stackdriver Logging and Monitoring are enabled | `cluster.tf`: `logging_config` and `monitoring_config` with all components |
| 6.2 | Ensure private cluster is enabled when creating GKE | `cluster.tf`: `enable_private_nodes=true`; prod: `enable_private_endpoint=true` |
| 6.3 | Ensure Cluster-level logging/monitoring is enabled | `cluster.tf`: managed Prometheus enabled |
| 6.4 | Ensure legacy metadata APIs are disabled | `node_pools.tf`: `disable-legacy-endpoints=true` |
| 6.5 | Ensure Container-Optimized OS is used | `node_pools.tf`: `image_type=COS_CONTAINERD` |
| 6.6 | Ensure master authorized networks is enabled | `cluster.tf`: `master_authorized_networks_config` with explicit CIDRs |
| 6.7 | Ensure clusters are not running basic authentication | `cluster.tf`: `client_certificate_config.issue_client_certificate=false` |
| 6.8 | Ensure Workload Identity is enabled | `cluster.tf`: `workload_identity_config`; `node_pools.tf`: `mode=GKE_METADATA` |
| 6.9 | Ensure pod security admission is enabled | OPA Gatekeeper constraints replace deprecated PSP |
| 6.10 | Ensure Kubernetes Secrets are encrypted at rest | `cluster.tf`: `database_encryption` with KMS key |
| 6.11 | Ensure network policy is enabled | `cluster.tf`: `network_policy.enabled=true`, Calico provider |
| 6.12 | Ensure Binary Authorization is enabled | `cluster.tf`: `evaluation_mode=PROJECT_SINGLETON_POLICY_ENFORCE` |
