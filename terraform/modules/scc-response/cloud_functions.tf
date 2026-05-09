resource "google_service_account" "scc_responder" {
  project      = var.project_id
  account_id   = "scc-auto-responder"
  display_name = "SCC Auto-Response Cloud Function SA"
  description  = "Least-privilege SA for the SCC automated response Cloud Function"
}

# Permissions needed for automated remediation actions
resource "google_project_iam_member" "responder_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.scc_responder.email}"
}

resource "google_project_iam_member" "responder_compute_security" {
  project = var.project_id
  role    = "roles/compute.securityAdmin"
  member  = "serviceAccount:${google_service_account.scc_responder.email}"
}

resource "google_project_iam_member" "responder_iam_admin" {
  project = var.project_id
  role    = "roles/resourcemanager.projectIamAdmin"
  member  = "serviceAccount:${google_service_account.scc_responder.email}"
}

resource "google_project_iam_member" "responder_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.scc_responder.email}"
}

resource "google_project_iam_member" "responder_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.scc_responder.email}"
}

resource "google_cloudfunctions2_function" "scc_responder" {
  name     = "scc-auto-responder"
  location = var.region
  project  = var.project_id

  build_config {
    runtime     = "python311"
    entry_point = "handle_finding"

    source {
      storage_source {
        bucket = var.function_source_bucket
        object = var.function_source_object
      }
    }
  }

  service_config {
    min_instance_count             = 0
    max_instance_count             = 10
    available_memory               = "256M"
    timeout_seconds                = 60
    service_account_email          = google_service_account.scc_responder.email
    ingress_settings               = "ALLOW_INTERNAL_ONLY"
    all_traffic_on_latest_revision = true

    environment_variables = {
      PROJECT_ID = var.project_id
      ORG_ID     = var.org_id
      DRY_RUN    = "false"
    }

    secret_environment_variables {
      key        = "SLACK_WEBHOOK_URL"
      project_id = var.project_id
      secret     = var.slack_webhook_secret_id
      version    = "latest"
    }
  }

  event_trigger {
    trigger_region        = var.region
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic          = google_pubsub_topic.scc_findings.id
    retry_policy          = "RETRY_POLICY_RETRY"
    service_account_email = google_service_account.scc_responder.email
  }
}
