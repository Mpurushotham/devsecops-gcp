variable "org_id" { type = string }
variable "billing_account_id" { type = string }
variable "region" { type = string; default = "us-central1" }
variable "notification_email" { type = string }
variable "github_org" { type = string }
variable "github_repo" { type = string; default = "devsecops-gcp" }
variable "staging_folder_id" { type = string; description = "Staging folder ID from folder-hierarchy module" }
variable "security_folder_id" { type = string }
variable "access_policy_name" { type = string; description = "Access Context Manager policy name for VPC-SC" }
variable "function_source_bucket" { type = string; description = "GCS bucket containing Cloud Function source zips" }
