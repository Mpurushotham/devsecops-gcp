variable "project_id" { type = string }
variable "org_id" { type = string }
variable "region" {
  type    = string
  default = "us-central1"
}
variable "environment" { type = string }
variable "notification_email" {
  type        = string
  description = "Email address for monitoring alerts"
}
variable "pagerduty_key" {
  type        = string
  description = "PagerDuty integration key for critical alerts"
  default     = ""
  sensitive   = true
}
