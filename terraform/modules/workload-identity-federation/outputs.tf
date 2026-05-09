output "workload_sa_emails" {
  description = "Map of workload name to GCP SA email"
  value       = { for k, sa in google_service_account.workload_sa : k => sa.email }
}

output "workload_pool" {
  description = "Workload Identity Pool name for the project"
  value       = "${var.project_id}.svc.id.goog"
}
