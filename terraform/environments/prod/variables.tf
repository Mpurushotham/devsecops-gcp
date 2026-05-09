variable "org_id" { type = string }
variable "billing_account_id" { type = string }
variable "region" { type = string; default = "us-central1" }
variable "notification_email" { type = string }
variable "github_org" { type = string }
variable "github_repo" { type = string; default = "devsecops-gcp" }
variable "prod_folder_id" { type = string; description = "Prod folder ID from folder-hierarchy module" }
variable "security_folder_id" { type = string }
variable "access_policy_name" { type = string; description = "Access Context Manager policy name for VPC-SC" }
variable "pagerduty_key" { type = string; sensitive = true; default = "" }
variable "bastion_cidr" { type = string; description = "CIDR of the bastion host for authorized GKE master access" }
variable "vpc_sc_allowed_members" { type = list(string); description = "Members (identities) allowed to access VPC-SC perimeter resources"; default = [] }
variable "function_source_bucket" { type = string; description = "GCS bucket containing Cloud Function source zips" }
