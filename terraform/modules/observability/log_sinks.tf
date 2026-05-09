resource "google_bigquery_dataset" "audit_logs" {
  dataset_id  = "audit_logs"
  project     = var.project_id
  location    = var.region
  description = "Centralized audit log sink — partitioned by day"

  delete_contents_on_destroy = false

  access {
    role          = "OWNER"
    special_group = "projectOwners"
  }
}

resource "google_storage_bucket" "log_archive" {
  name          = "${var.project_id}-audit-archive"
  project       = var.project_id
  location      = var.region
  force_destroy = false

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # 7-year retention for SOC 2 compliance
  retention_policy {
    retention_period = 220752000 # 7 years in seconds
    is_locked        = true
  }

  lifecycle_rule {
    condition {
      age = 365
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  lifecycle_rule {
    condition {
      age = 1095
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }
}

resource "google_project_iam_member" "log_sink_bq_writer" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${var.project_id}@logging.iam.gserviceaccount.com"
}
