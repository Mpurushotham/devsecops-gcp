output "seed_project_id" {
  description = "Seed project ID — use as GCP_PROJECT_SEED GitHub Actions variable"
  value       = google_project.seed.project_id
}

output "tfstate_bucket_name" {
  description = "GCS bucket name for Terraform remote state"
  value       = google_storage_bucket.tfstate.name
}

output "wif_provider_name" {
  description = "Full WIF provider resource name — set as WIF_PROVIDER GitHub Actions variable"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "wif_provider_main_name" {
  description = "WIF provider restricted to main branch — use for apply SA"
  value       = google_iam_workload_identity_pool_provider.github_main.name
}

output "terraform_plan_sa_email" {
  description = "Terraform plan SA email — set as TERRAFORM_SA_DEV/STAGING/PROD GitHub Actions variables"
  value       = google_service_account.terraform_plan.email
}

output "terraform_apply_sa_email" {
  description = "Terraform apply SA email — set as TERRAFORM_APPLY_SA_DEV/STAGING/PROD GitHub Actions variables"
  value       = google_service_account.terraform_apply.email
}

output "image_push_sa_email" {
  description = "Image push SA email — set as IMAGE_PUSH_SA GitHub Actions variable"
  value       = google_service_account.image_push.email
}

output "prowler_sa_email" {
  description = "Prowler SA email — set as PROWLER_SA GitHub Actions variable"
  value       = google_service_account.prowler.email
}

output "next_steps" {
  description = "Post-bootstrap steps"
  value       = <<-EOT
    Bootstrap complete. Next steps:
    1. Migrate state: update backend.tf to GCS, run 'terraform init -migrate-state'
    2. Set GitHub Actions variables:
       - WIF_PROVIDER = ${google_iam_workload_identity_pool_provider.github.name}
       - TERRAFORM_SA_DEV = ${google_service_account.terraform_plan.email}
       - TERRAFORM_APPLY_SA_DEV = ${google_service_account.terraform_apply.email}
       - IMAGE_PUSH_SA = ${google_service_account.image_push.email}
       - PROWLER_SA = ${google_service_account.prowler.email}
    3. Revoke roles/resourcemanager.organizationAdmin and roles/billing.admin
       from the apply SA after org foundation is deployed.
  EOT
}
