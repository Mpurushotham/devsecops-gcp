variable "security_reviewer_sa" {
  description = "Service account email for the audit/security reviewer role"
  type        = string
  default     = ""
}

resource "google_organization_iam_member" "security_reviewer" {
  count  = var.security_reviewer_sa != "" ? 1 : 0
  org_id = var.org_id
  role   = "roles/iam.securityReviewer"
  member = "serviceAccount:${var.security_reviewer_sa}"
}

resource "google_organization_iam_member" "log_sink_bigquery" {
  org_id = var.org_id
  role   = "roles/logging.configWriter"
  member = google_logging_organization_sink.bq_audit.writer_identity
}
