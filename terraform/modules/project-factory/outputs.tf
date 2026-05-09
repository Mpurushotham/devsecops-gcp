output "project_id" {
  description = "The generated GCP project ID"
  value       = google_project.project.project_id
}

output "project_number" {
  description = "The GCP project number"
  value       = google_project.project.number
}

output "project_name" {
  description = "The project display name"
  value       = google_project.project.name
}
