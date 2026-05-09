variable "org_id" {
  description = "GCP Organization ID (numeric, e.g. 123456789012)"
  type        = string
}

variable "billing_account_id" {
  description = "GCP Billing Account ID (e.g. ABCDEF-123456-ABCDEF)"
  type        = string
}

variable "seed_project_name" {
  description = "Display name for the seed/bootstrap project"
  type        = string
  default     = "devsecops-bootstrap"
}

variable "region" {
  description = "Primary GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "github_org" {
  description = "GitHub organization or user name (used in WIF attribute condition)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (used in WIF attribute condition)"
  type        = string
  default     = "devsecops-gcp"
}

variable "terraform_sa_name" {
  description = "Service account name used by Terraform CI for plan operations"
  type        = string
  default     = "github-terraform-plan"
}

variable "terraform_apply_sa_name" {
  description = "Service account name used by Terraform CI for apply operations (main branch only)"
  type        = string
  default     = "github-terraform-apply"
}

variable "image_push_sa_name" {
  description = "Service account name for container image push and Binary Authorization"
  type        = string
  default     = "github-image-push"
}

variable "prowler_sa_name" {
  description = "Service account name for Prowler compliance scans"
  type        = string
  default     = "github-prowler"
}
