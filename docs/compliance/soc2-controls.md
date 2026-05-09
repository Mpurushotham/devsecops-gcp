# SOC 2 Type II — Control Mapping

## CC6 — Logical and Physical Access Controls

| Control | Requirement | Implementation |
|---|---|---|
| CC6.1 | Logical access security measures | WIF (no long-lived keys); MFA enforced via Google Workspace; Org policy disables SA key creation |
| CC6.2 | Authentication and authorization | IAM least-privilege; custom roles; Workload Identity for GKE pods |
| CC6.3 | Role-based access | Separate SAs per function (plan, apply, image-push, prowler); folder-level IAM inheritance |
| CC6.6 | System boundary protection | VPC Service Controls perimeter; private GKE endpoint (prod); Binary Authorization |
| CC6.7 | Transmission encryption | TLS enforced on all endpoints; Private Google Access; KMS CMEK for data at rest |
| CC6.8 | Restriction of access | IAP-only SSH; no direct SSH from internet; network policies default-deny |

## CC7 — System Operations

| Control | Requirement | Implementation |
|---|---|---|
| CC7.1 | Threat detection | Falco runtime rules; SCC Event Threat Detection; Cloud Armor WAF |
| CC7.2 | Monitoring of system components | Cloud Monitoring alert policies (8 security alerts); GKE managed Prometheus; Prowler daily scans |
| CC7.3 | Incident response | SCC → Pub/Sub → Cloud Function automated response; incident-response runbook in `docs/runbooks/` |
| CC7.4 | Security incidents | Automated Slack/PagerDuty alerting; SCC finding notifications; Falco CRITICAL-level paging |
| CC7.5 | Remediation of identified deficiencies | Prowler SARIF reports in GitHub Security tab; automated remediation Cloud Function |

## CC8 — Change Management

| Control | Requirement | Implementation |
|---|---|---|
| CC8.1 | Change management process | All changes via Terraform PRs; required PR reviews (CODEOWNERS); GitHub Environment gates for staging/prod |

## A1 — Availability

| Control | Requirement | Implementation |
|---|---|---|
| A1.1 | Capacity planning | GKE HPA + cluster autoscaler; budget alerts at 50/75/90/100% |
| A1.2 | Availability monitoring | Cloud Monitoring uptime checks; GKE regional cluster (multi-AZ); Cloud Armor DDoS protection |
| A1.3 | Recovery from failures | GKE self-healing (auto-repair, auto-upgrade); managed node pools with surge upgrade |

## Evidence Collection for Auditors

The following artifacts are automatically generated and retained for SOC 2 evidence:

| Evidence | Source | Retention | Location |
|---|---|---|---|
| Audit logs | Cloud Logging org sink | 7 years | GCS bucket `*-audit-archive` |
| Audit logs (queryable) | BigQuery sink | Partitioned, indefinite | BigQuery dataset `audit_logs` |
| Compliance scan results | Prowler CI (daily) | 90 days | GitHub Actions artifacts |
| Vulnerability scan results | Trivy/Grype CI | Per-PR | GitHub Security tab (SARIF) |
| SBOM per release | Syft + GitHub Attestations | Indefinite | GitHub release assets |
| IaC change history | GitHub git log | Indefinite | GitHub repository |
| Access review | IAM policy snapshots | Via Prowler reports | GitHub Actions artifacts |
| Incident records | SCC finding history | Indefinite | SCC console |
