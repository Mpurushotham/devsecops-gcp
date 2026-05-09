variable "project_name" {
  description = "Display name of the GCP project"
  type        = string
}

variable "project_id_prefix" {
  description = "Prefix for the project ID (a random suffix is appended)"
  type        = string
}

variable "folder_id" {
  description = "Folder ID to create the project in"
  type        = string
}

variable "billing_account_id" {
  description = "Billing account ID to associate with the project"
  type        = string
}

variable "environment" {
  description = "Environment label (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod", "shared", "security", "bootstrap"], var.environment)
    error_message = "environment must be one of: dev, staging, prod, shared, security, bootstrap"
  }
}

variable "activate_apis" {
  description = "List of GCP APIs to enable in the project"
  type        = list(string)
  default     = []
}

variable "default_apis" {
  description = "APIs enabled in every project regardless of type"
  type        = list(string)
  default = [
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudkms.googleapis.com",
    "servicenetworking.googleapis.com",
    "compute.googleapis.com",
  ]
}

variable "budget_amount" {
  description = "Monthly budget amount in USD"
  type        = number
  default     = 500
}

variable "budget_alert_emails" {
  description = "Email addresses to receive budget alerts"
  type        = list(string)
  default     = []
}

variable "labels" {
  description = "Additional labels to apply to the project"
  type        = map(string)
  default     = {}
}
