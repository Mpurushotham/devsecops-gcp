# Security Model

## Design Principles

1. **No long-lived credentials** — GitHub Actions authenticates to GCP exclusively via Workload Identity Federation (OIDC). No service account keys exist outside of emergency break-glass scenarios.
2. **Defense in depth** — security controls exist at every layer: org policies, IAM, VPC, container runtime, and CI/CD pipeline.
3. **Shift left** — security scanning (SAST, SCA, IaC, secrets) happens before any code reaches main branch.
4. **Deny by default** — firewall, network policies, Gatekeeper, and Binary Authorization all start from a deny-all baseline.
5. **Automated response** — SCC findings for known-bad conditions (public buckets, open firewalls, crypto miners) trigger automated remediation without human latency.
6. **Immutable audit trail** — all API activity is captured to Cloud Logging with 7-year LOCKED retention in GCS.

---

## Authentication & Authorization Layers

### GitHub Actions → GCP (No Keys)

```
GitHub Actions runner
  → OIDC token (github.com/login/oauth/access_token)
  → WIF Provider validates token (issuer, repo, audience)
  → Impersonate Service Account
  → Short-lived GCP access token (1 hour)
```

Two WIF providers exist:
- **Any-branch provider**: used by plan SA — allows any branch in the repo
- **Main-branch provider**: used by apply SA — restricts to `assertion.ref == "refs/heads/main"`

This ensures `terraform apply` can only run from the main branch, even if someone gains write access to a feature branch.

### GKE Workload Identity

```
Pod (with serviceAccountName annotation)
  → GKE Metadata Server (no external call)
  → GCP Service Account token
  → Scoped GCP API access
```

Application pods never mount SA key files. Workload Identity binds Kubernetes SAs to GCP SAs via annotation + IAM binding.

### Human Access

- All console/API access via GCP Identity (Google Workspace accounts)
- `os-login` enforced on all Compute instances (no SSH keys in instance metadata)
- IAP used for SSH to any bastion or compute instance
- No primitive roles (`roles/owner`, `roles/editor`) assigned to humans on prod

---

## IAM Design

### Service Account Inventory

| SA | Permissions | Used By |
|---|---|---|
| `github-terraform-plan` | `roles/viewer`, plan-level read on all modules | WIF (any branch) |
| `github-terraform-apply` | Module-specific write roles | WIF (main branch only) |
| `github-image-push` | `roles/artifactregistry.writer` | Workflow 04 |
| `github-prowler` | `roles/viewer`, `roles/iam.securityReviewer` | Workflow 06 |
| `gke-node-sa` | `logging.logWriter`, `monitoring.metricWriter`, `artifactregistry.reader` | GKE node pools |
| `scc-responder` | `storage.admin`, `compute.securityAdmin`, `resourcemanager.projectIamAdmin` | Cloud Functions v2 |
| `falco-sidekick` | `pubsub.publisher` | Falcosidekick Helm |

### Org Policies (Preventive Controls)

Org policies enforce invariants that IAM cannot: even `roles/owner` cannot violate them.

| Constraint | Setting | Effect |
|---|---|---|
| `iam.disableServiceAccountKeyCreation` | Enforce | No SA key files |
| `iam.disableServiceAccountKeyUpload` | Enforce | No external key imports |
| `compute.skipDefaultNetworkCreation` | Enforce | No default VPC |
| `compute.vmExternalIpAccess` | Deny All | No public VM IPs |
| `storage.publicAccessPrevention` | Enforce | No public GCS buckets |
| `gcp.resourceLocations` | US locations | Data residency |
| `compute.requireOsLogin` | Enforce | SSH via IAP only |
| `compute.restrictCloudRunRegions` | US | Data residency |
| `iam.allowedPolicyMemberDomains` | Org domain | No external IAM grants |

---

## Container Security Layers

### CI/CD Pipeline (Workflow 04)

```
git push
  → Build image (no push yet)
  → Trivy image scan (CRITICAL/HIGH = fail)
  → Grype scan
  → Syft SBOM generation + attestation
  → Cosign sign (KMS or keyless)
  → Push to Artifact Registry
  → Binary Authorization attestation
```

Image is never pushed to the registry until scans pass. Attestation is created before any deployment job can run.

### Binary Authorization

Clusters are configured with `PROJECT_SINGLETON_POLICY_ENFORCE`. Every Pod admission is checked against the policy:

| Environment | Policy | Effect |
|---|---|---|
| dev | `ALWAYS_ALLOW` + DRYRUN audit | Audit only, no blocking |
| staging | `ALWAYS_ALLOW` + DRYRUN audit | Audit only, no blocking |
| prod | `DENY_ALL` unless attested | Only CI-built, scanned images |

GKE system images and images from `gcr.io/google-containers/` are exempted via image allowlist in the Binary Auth policy.

### OPA Gatekeeper (Runtime Admission)

ConstraintTemplates enforce Kubernetes-level policies:

| Policy | Enforcement | Checks |
|---|---|---|
| `K8sNoRoot` | dryrun | `runAsUser != 0`, `runAsNonRoot = true` |
| `K8sNoPodPrivilege` | deny | `privileged != true` |
| `K8sReadOnlyRootFilesystem` | dryrun | `readOnlyRootFilesystem = true` |
| `K8sAllowedRepos` | deny | Image from Artifact Registry only |
| `K8sRequiredLabels` | dryrun | `app`, `team`, `version` labels |
| `K8sHostNamespace` | deny | No `hostPID`, `hostIPC`, `hostNetwork` |
| `K8sHostFilesystem` | deny | No host path mounts outside allowlist |
| `K8sRequiredSecurityContext` | dryrun | `allowPrivilegeEscalation=false`, `drop ALL` |
| `K8sResourceLimits` | dryrun | CPU + memory limits required |
| `K8sRequiredProbes` | dryrun | Liveness + readiness probes required |

Gatekeeper lifecycle: all new policies start in `dryrun`. Flip to `deny` after validating no legitimate workloads are blocked.

### Falco (Runtime Threat Detection)

Falco uses the eBPF driver on Standard node pools to detect anomalous syscall patterns at the kernel level. Custom rulesets:

| Ruleset | Detects |
|---|---|
| `gcp-specific.yaml` | GCP metadata server access, credential file reads, kubectl in containers |
| `crypto-mining.yaml` | Known miner processes (xmrig, cgminer), stratum+tcp connections, mining pool domains |
| `data-exfiltration.yaml` | Large outbound data (>100MB excluding googleapis), sensitive file reads, unexpected shells |
| `privilege-escalation.yaml` | sudo/su, setuid/setgid, nsenter namespace escape, /proc writes |

Falco events → Falcosidekick → GCP Pub/Sub → Cloud Functions response or alert.

---

## Encryption

### In Transit

- All GCP service communication encrypted via TLS 1.2+ (platform-enforced)
- GKE pod-to-pod encrypted via `ADVANCED_DATAPATH` (eBPF/WireGuard)
- External HTTPS via Google-managed SSL certificates

### At Rest

All data encrypted with Customer-Managed Encryption Keys (CMEK):

| Resource | KMS Key |
|---|---|
| GKE etcd | `gke-secrets-key` |
| GCS buckets | `gcs-key` |
| Secret Manager | `secret-manager-key` |
| Artifact Registry | `artifact-registry-key` |
| Binary Auth signing | `binauthz-attestor-key` (EC_SIGN_P256_SHA256) |

All keys: 90-day rotation period, `prevent_destroy = true`.

---

## Audit Logging

### GCP Audit Logs

Configured at org level via `google_organization_iam_audit_config`:
- `DATA_READ`, `DATA_WRITE`, `ADMIN_READ` for all services
- Covers: API calls, resource mutations, data access

### Sinks

| Sink | Destination | Filter | Retention |
|---|---|---|---|
| BQ sink | BigQuery dataset (partitioned by day) | Audit logs only | 90 days (BQ default) |
| GCS archive | GCS bucket (LOCKED retention) | All audit + severity >= WARNING | 7 years |

The GCS bucket uses a `LOCKED` retention policy — not even a project owner can delete objects before expiry. This satisfies SOC 2 evidence immutability requirements.

### Key Events Alerted

| Event | Alert Policy |
|---|---|
| SA key created | `iam_key_created` |
| Org policy modified | `org_policy_changed` |
| Firewall rule changed | `firewall_modified` |
| GKE cluster modified | `gke_cluster_modified` |
| SCC CRITICAL/HIGH finding | `scc_critical_finding` |
| Binary Auth violation | `binary_auth_violation` |
| Budget threshold exceeded | `budget_exceeded` |
| Anomalous IAM grant | `anomalous_iam_grant` |

---

## Threat Model Summary

| Threat | Controls |
|---|---|
| Leaked credentials in code | gitleaks + trufflehog in CI, no SA keys (WIF) |
| Compromised GitHub Actions | WIF OIDC with repo/branch conditions, min-permission SAs |
| Malicious container image | Binary Auth attestation, Trivy/Grype scan, allowed-repos Gatekeeper |
| Container escape | Falco eBPF, no-privileged Gatekeeper, read-only rootfs |
| Data exfiltration via GCP API | VPC-SC perimeter, Falco data exfiltration rules |
| Public storage bucket | Org policy (publicAccessPrevention), SCC auto-remediation |
| Cryptominer in cluster | Falco crypto-mining rules, automated Pod stop |
| IAM privilege escalation | Org policies (no external grants), SCC anomalous IAM grant alert |
| Network-based attack | Deny-all firewall, NetworkPolicy default-deny, no public node IPs |
| Insider threat (infra change) | All changes via PR, CODEOWNERS, GitHub Environment gates, audit logs |

---

## Related

- Network design: `docs/architecture/network-design.md`
- Threat response: `docs/architecture/threat-response.md`
- CIS GCP mapping: `docs/compliance/cis-gcp-mapping.md`
- SOC 2 controls: `docs/compliance/soc2-controls.md`
- Incident response runbook: `docs/runbooks/incident-response.md`
