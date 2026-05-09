variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "Primary GCP region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "kms_key_rotation_period" {
  description = "Rotation period for KMS keys in seconds (default 90 days)"
  type        = string
  default     = "7776000s"
}

variable "binary_auth_mode" {
  description = "Binary Authorization admission rule mode: WARN or DENY_ALL"
  type        = string
  default     = "WARN"
  validation {
    condition     = contains(["WARN", "DENY_ALL"], var.binary_auth_mode)
    error_message = "binary_auth_mode must be WARN or DENY_ALL"
  }
}

variable "gke_sa_email" {
  description = "GKE node pool service account email (needs KMS decrypt access)"
  type        = string
  default     = ""
}

variable "artifact_registry_sa_email" {
  description = "Artifact Registry service account email (needs KMS encrypt/decrypt)"
  type        = string
  default     = ""
}
