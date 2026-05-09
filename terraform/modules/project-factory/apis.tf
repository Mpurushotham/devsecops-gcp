resource "google_project_service" "apis" {
  for_each = toset(concat(var.default_apis, var.activate_apis))

  project = google_project.project.project_id
  service = each.value

  # Never disable APIs on destroy — could break running services
  disable_on_destroy         = false
  disable_dependent_services = false
}

# Remove the default VPC network created by GCP (CIS 3.1)
resource "google_compute_network" "default_vpc" {
  name    = "default"
  project = google_project.project.project_id

  # This data source-based trick: import the default network then destroy it
  # In practice, use a null_resource or gcloud command; Terraform cannot directly
  # delete a network it didn't create. Use lifecycle to trigger deletion.
  lifecycle {
    prevent_destroy = false
  }

  depends_on = [google_project_service.apis]
}

# Delete default VPC immediately after project creation
resource "terraform_data" "delete_default_vpc" {
  input = google_project.project.project_id

  provisioner "local-exec" {
    command = <<-EOT
      gcloud compute networks delete default \
        --project="${self.input}" \
        --quiet \
        2>/dev/null || true
    EOT
  }

  depends_on = [google_project_service.apis]
}
