# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

`devsecops-gcp` is a production-grade DevSecOps platform on Google Cloud Platform built with:
- **IaC**: Terraform (HCL), all modules under `terraform/modules/`, instantiated per-environment under `terraform/environments/`
- **CI/CD**: GitHub Actions (10 workflows in `.github/workflows/`)
- **Compliance**: CIS GCP Benchmarks v2.0 + SOC 2 Type II, enforced via Prowler, OPA/conftest, and Gatekeeper
- **Auth**: GitHub Actions → GCP via Workload Identity Federation (OIDC) — no long-lived credentials anywhere

## Common Commands

### Terraform

```bash
# Bootstrap (run once manually as org admin)
cd terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars   # fill in org_id, billing_account_id, github_org
terraform init && terraform plan && terraform apply

# Per-environment workflow
cd terraform/environments/dev
terraform init
terraform validate
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars

# Format all Terraform files
terraform fmt -recursive terraform/

# Validate a specific module in isolation
cd terraform/modules/gke
terraform init -backend=false && terraform validate
```

### Pre-commit

```bash
# Install hooks once
pip install pre-commit
pre-commit install

# Run all hooks manually
pre-commit run --all-files

# Run a specific hook
pre-commit run terraform_fmt --all-files
pre-commit run gitleaks --all-files
```

### OPA / Conftest (Terraform plan policy checks)

```bash
# Generate plan JSON, then test against OPA policies
cd terraform/environments/dev
terraform plan -out=tfplan.binary && terraform show -json tfplan.binary > tfplan.json
conftest test tfplan.json --policy ../../compliance/opa-policies/gcp/

# Run OPA unit tests for Gatekeeper constraint templates
opa test kubernetes/gatekeeper/constraint-templates/ -v
opa test compliance/opa-policies/ -v
```

### Prowler (compliance scanning)

```bash
# Requires: pip install prowler; gcloud auth application-default login
prowler gcp \
  --compliance cis_gcp_2.0 \
  --compliance soc2 \
  --output-formats html json \
  --output-directory compliance/reports/ \
  --project-ids "YOUR_PROJECT_ID"
```

### Cloud Functions (local test)

```bash
cd cloud-functions/scc-auto-response
pip install -r requirements.txt
python -m pytest test_main.py -v
```

### Kubernetes / Helm

```bash
# Apply Gatekeeper constraint templates (start in dryrun mode)
kubectl apply -f kubernetes/gatekeeper/install/gatekeeper.yaml
kubectl apply -f kubernetes/gatekeeper/constraint-templates/
kubectl apply -f kubernetes/gatekeeper/constraints/

# Check for Gatekeeper violations
kubectl get constraints -A
kubectl describe k8snoroot no-root-containers

# Deploy Falco via Helm
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm install falco falcosecurity/falco \
  --namespace falco-system --create-namespace \
  -f kubernetes/falco/values.yaml \
  -f kubernetes/falco/custom-rules/gcp-specific.yaml

# Apply network policies
kubectl apply -f kubernetes/network-policies/
```

## Architecture

### Module Dependency Order

Bootstrap must run first (manually). All other modules are deployed by CI:

```
bootstrap/
  └─► folder-hierarchy → org-foundation
                       → project-factory → networking
                                         → artifact-registry
                                         → security-baseline → gke
                                         → workload-identity-federation
                                         → scc-response
                                         → observability
```

### Environments

Each environment (`dev/`, `staging/`, `prod/`) is an independent Terraform root that instantiates all modules. Key differences:

| Setting | dev | staging | prod |
|---|---|---|---|
| `binary_auth_mode` | `WARN` | `WARN` | `DENY_ALL` |
| `enable_private_endpoint` (GKE) | `false` | `false` | `true` |
| VPC-SC mode | disabled | `DRY_RUN` | `ENFORCE` |
| Gatekeeper enforcement | `dryrun` | mixed | `deny` |

### CI Pipeline Flow

PR → `00` secret scan → `01` IaC scan (tfsec/checkov) → `02` SAST → `03` SCA → `07` terraform plan (comment on PR)

Merge to main → `04` container build/scan/attest/push → `08` terraform apply (dev auto, staging 1 reviewer, prod 2 reviewers)

Scheduled daily → `06` Prowler compliance scan

### Authentication (GitHub → GCP)

All GCP access from GitHub Actions uses Workload Identity Federation — no service account keys. Four separate SAs, each bound to the WIF pool:
- `github-terraform-plan` — read-only, any branch
- `github-terraform-apply` — write, main branch only (separate WIF provider with `assertion.ref` condition)
- `github-image-push` — Artifact Registry write + Binary Authorization
- `github-prowler` — org-wide viewer + securityReviewer

Required GitHub Actions variables: `WIF_PROVIDER`, `TERRAFORM_SA_DEV/STAGING/PROD`, `TERRAFORM_APPLY_SA_DEV/STAGING/PROD`, `IMAGE_PUSH_SA`, `PROWLER_SA`, `GCP_PROJECT_DEV/STAGING/PROD`, `AR_REPO`, `BINAUTHZ_ATTESTOR`, `BINAUTHZ_KMS_KEY_VERSION`.

### SCC Automated Response

SCC finding → Pub/Sub topic `scc-findings` → Cloud Function `scc-auto-responder` → GCP remediation API.

The Cloud Function (`cloud-functions/scc-auto-response/main.py`) dispatches by `finding.category`. Start with `DRY_RUN=true` in the function env var; flip to `false` after validating in staging.

### Gatekeeper Constraint Lifecycle

New constraints always start with `enforcementAction: dryrun`. After running `kubectl get constraints -A` shows zero violations for 48h, flip to `deny`. Do not flip multiple constraints simultaneously.

## Critical Conventions

**VPC-SC**: Always start with `vpc_sc_mode = "DRY_RUN"` and observe `cloudaudit.googleapis.com/data_access` violations for at least one week. Switching to `ENFORCE` with a misconfigured perimeter breaks all API access within it instantly.

**Binary Authorization ordering in workflow `04`**: build → scan → attest (only if scan passes) → push. The attestation must exist before any downstream `kubectl` apply or Cloud Deploy trigger runs. Never push first and attest later — a `DENY_ALL` cluster will reject the image before attestation arrives.

**Private GKE endpoint (prod)**: With `enable_private_endpoint = true`, `kubectl` and `helm` from GitHub Actions cannot reach the API server directly. Route through `gcloud builds submit` (Cloud Build runs inside the VPC) for all cluster operations in prod.

**Bootstrap SA cleanup**: After Phase 1 completes, remove `roles/resourcemanager.organizationAdmin` and `roles/billing.admin` from the Terraform apply SA. These are temporary bootstrap permissions only.

**`terraform.tfvars` is gitignored** — never commit it. Use `terraform.tfvars.example` to document new variables.

**KMS keys have `prevent_destroy = true`** — destroying them would permanently lose data encrypted with those keys. Remove the lifecycle rule explicitly if you intentionally need to delete a key.
