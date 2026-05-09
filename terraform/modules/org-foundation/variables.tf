variable "org_id" {
  description = "GCP Organization ID"
  type        = string
}

variable "billing_account_id" {
  description = "GCP Billing Account ID"
  type        = string
}

variable "logging_project_id" {
  description = "Project ID of the centralized logging project"
  type        = string
}

variable "scc_pubsub_topic" {
  description = "Full Pub/Sub topic resource name for SCC finding notifications"
  type        = string
}

variable "allowed_regions" {
  description = "List of allowed GCP regions for resource location constraint"
  type        = list(string)
  default     = ["us-central1", "us-east1", "us-west1"]
}

variable "audit_sa_email" {
  description = "Service account email for audit log sink writer"
  type        = string
  default     = ""
}
