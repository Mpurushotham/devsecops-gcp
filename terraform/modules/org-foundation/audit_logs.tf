# Enable DATA_READ, DATA_WRITE, and ADMIN_READ audit logs for all services org-wide
resource "google_organization_iam_audit_config" "all_services" {
  org_id  = var.org_id
  service = "allServices"

  audit_log_config {
    log_type = "DATA_READ"
  }

  audit_log_config {
    log_type = "DATA_WRITE"
  }

  audit_log_config {
    log_type = "ADMIN_READ"
  }
}

# Org-level log sink to BigQuery for queryable audit trail
resource "google_logging_organization_sink" "bq_audit" {
  name             = "org-audit-to-bigquery"
  org_id           = var.org_id
  destination      = "bigquery.googleapis.com/projects/${var.logging_project_id}/datasets/audit_logs"
  include_children = true

  filter = <<-EOT
    logName=~"cloudaudit.googleapis.com" OR
    logName=~"data_access" OR
    logName=~"activity" OR
    resource.type="gke_cluster" OR
    resource.type="gce_firewall_rule" OR
    resource.type="iam_role"
  EOT

  bigquery_options {
    use_partitioned_tables = true
  }
}

# Org-level log sink to GCS for long-term compliance archive (SOC 2 requires 7 years)
resource "google_logging_organization_sink" "gcs_archive" {
  name             = "org-audit-to-gcs"
  org_id           = var.org_id
  destination      = "storage.googleapis.com/org-audit-archive-${var.org_id}"
  include_children = true

  filter = <<-EOT
    logName=~"cloudaudit.googleapis.com" OR
    severity >= WARNING
  EOT
}

# Grant the log sink service accounts write access to their destinations
resource "google_project_iam_member" "bq_sink_writer" {
  project = var.logging_project_id
  role    = "roles/bigquery.dataEditor"
  member  = google_logging_organization_sink.bq_audit.writer_identity
}
