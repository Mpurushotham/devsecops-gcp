variable "org_id" { type = string }
variable "billing_account_id" { type = string }
variable "region" { type = string; default = "us-central1" }
variable "notification_email" { type = string }
variable "github_org" { type = string }
variable "github_repo" { type = string; default = "devsecops-gcp" }
variable "dev_folder_id" { type = string; description = "Dev folder ID from folder-hierarchy module" }
variable "security_folder_id" { type = string }
variable "function_source_bucket" { type = string; description = "GCS bucket containing Cloud Function source zips" }
