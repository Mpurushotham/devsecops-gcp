# Bootstrap

Run once, manually, by a GCP Organization Admin. Creates the seed project, Terraform remote state bucket, and Workload Identity Federation configuration for GitHub Actions.

## Prerequisites

- GCP Organization created
- Billing account created and linked to the org
- `gcloud auth application-default login` as an org admin
- Terraform >= 1.9

## Steps

```bash
cp terraform.tfvars.example terraform.tfvars
# Fill in terraform.tfvars with your org_id, billing_account_id, github_org

terraform init
terraform plan
terraform apply
```

After apply, migrate state to GCS:

```bash
# 1. Edit backend.tf — comment out "backend local", uncomment "backend gcs"
#    Set bucket = "<seed-project-id>-tfstate" from the output
terraform init -migrate-state
# 2. Confirm migration when prompted
# 3. Delete local terraform.tfstate
```

## Post-Bootstrap Cleanup (IMPORTANT)

After Phase 1 (org foundation) is deployed, revoke the temporary elevated permissions:

```bash
gcloud organizations remove-iam-policy-binding <ORG_ID> \
  --member="serviceAccount:<apply-sa-email>" \
  --role="roles/resourcemanager.organizationAdmin"

gcloud beta billing accounts remove-iam-policy-binding <BILLING_ID> \
  --member="serviceAccount:<apply-sa-email>" \
  --role="roles/billing.admin"
```

## GitHub Actions Variables to Set

After bootstrap, set these as repository-level variables (not secrets — they are not sensitive):

| Variable | Value |
|---|---|
| `WIF_PROVIDER` | Output: `wif_provider_name` |
| `TERRAFORM_SA_DEV` | Output: `terraform_plan_sa_email` |
| `TERRAFORM_SA_STAGING` | Output: `terraform_plan_sa_email` |
| `TERRAFORM_SA_PROD` | Output: `terraform_plan_sa_email` |
| `TERRAFORM_APPLY_SA_DEV` | Output: `terraform_apply_sa_email` |
| `TERRAFORM_APPLY_SA_STAGING` | Output: `terraform_apply_sa_email` |
| `TERRAFORM_APPLY_SA_PROD` | Output: `terraform_apply_sa_email` |
| `IMAGE_PUSH_SA` | Output: `image_push_sa_email` |
| `PROWLER_SA` | Output: `prowler_sa_email` |
