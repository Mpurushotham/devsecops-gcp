variable "project_id" { type = string }
variable "region" { type = string; default = "us-central1" }
variable "org_id" { type = string }
variable "kms_key_id" { type = string }
variable "function_source_bucket" { type = string; description = "GCS bucket containing the Cloud Function source zip" }
variable "function_source_object" { type = string; description = "GCS object path for the Cloud Function source zip" }
variable "slack_webhook_secret_id" { type = string; description = "Secret Manager secret ID for Slack webhook URL" }
