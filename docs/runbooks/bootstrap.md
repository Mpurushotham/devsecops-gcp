# Bootstrap Runbook

## Prerequisites

- GCP Organization created with billing account linked
- `gcloud` CLI installed and authenticated as an org admin
- Terraform >= 1.9 installed
- `gh` CLI authenticated to GitHub

## Step 1 — Bootstrap Terraform State and WIF

```bash
cd terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: set org_id, billing_account_id, github_org

terraform init
terraform plan    # review — expect ~15 resources
terraform apply
```

Save the outputs — you will need them in the next steps.

## Step 2 — Migrate State to GCS

```bash
# Edit backend.tf:
#   Comment out: backend "local" {}
#   Uncomment:   backend "gcs" { bucket = "<seed-project-id>-tfstate"; prefix = "bootstrap" }

terraform init -migrate-state
# Confirm when prompted: yes
rm -f terraform.tfstate terraform.tfstate.backup
```

## Step 3 — Set GitHub Actions Variables

In the GitHub repository settings → Variables, set:

```
WIF_PROVIDER             = <output: wif_provider_name>
TERRAFORM_SA_DEV         = <output: terraform_plan_sa_email>
TERRAFORM_SA_STAGING     = <output: terraform_plan_sa_email>
TERRAFORM_SA_PROD        = <output: terraform_plan_sa_email>
TERRAFORM_APPLY_SA_DEV   = <output: terraform_apply_sa_email>
TERRAFORM_APPLY_SA_STAGING = <output: terraform_apply_sa_email>
TERRAFORM_APPLY_SA_PROD  = <output: terraform_apply_sa_email>
IMAGE_PUSH_SA            = <output: image_push_sa_email>
PROWLER_SA               = <output: prowler_sa_email>
```

## Step 4 — Deploy Org Foundation

```bash
# Get folder IDs from the org
gcloud resource-manager folders list --organization=ORG_ID

# Edit terraform/environments/dev/terraform.tfvars with folder IDs
cd terraform/environments/dev
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## Step 5 — Post-Bootstrap Cleanup

After the org foundation is applied, remove temporary elevated permissions:

```bash
gcloud organizations remove-iam-policy-binding ORG_ID \
  --member="serviceAccount:APPLY_SA_EMAIL" \
  --role="roles/resourcemanager.organizationAdmin"

gcloud beta billing accounts remove-iam-policy-binding BILLING_ID \
  --member="serviceAccount:APPLY_SA_EMAIL" \
  --role="roles/billing.admin"
```

## Step 6 — Verify Workflows

Create a test PR that modifies a file in `terraform/`. Verify:
- Workflow `00-pre-checks` passes (gitleaks, pre-commit)
- Workflow `01-iac-security` passes (tfsec, checkov)
- Workflow `07-terraform-plan` posts a plan comment on the PR
