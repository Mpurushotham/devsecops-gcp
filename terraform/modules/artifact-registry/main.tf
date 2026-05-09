variable "project_id" { type = string }
variable "region" { type = string; default = "us-central1" }
variable "environment" { type = string }
variable "kms_key_id" { type = string; description = "KMS key ID for CMEK encryption" }

resource "google_artifact_registry_repository" "containers" {
  provider = google-beta

  project       = var.project_id
  location      = var.region
  repository_id = "${var.environment}-containers"
  format        = "DOCKER"
  description   = "${var.environment} container image registry"

  kms_key_name = var.kms_key_id

  docker_config {
    immutable_tags = var.environment == "prod" ? true : false
  }

  labels = {
    environment = var.environment
    managed-by  = "terraform"
  }
}

# Vulnerability scanning on push
resource "google_artifact_registry_repository" "containers_vuln" {
  provider = google-beta

  project       = var.project_id
  location      = var.region
  repository_id = "${var.environment}-containers-staging"
  format        = "DOCKER"
  description   = "Staging registry — images scanned here before promotion to ${var.environment}-containers"

  kms_key_name = var.kms_key_id

  labels = {
    environment = var.environment
    role        = "scan-staging"
    managed-by  = "terraform"
  }
}

output "registry_url" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.containers.repository_id}"
}

output "repository_id" {
  value = google_artifact_registry_repository.containers.repository_id
}
