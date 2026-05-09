resource "google_pubsub_topic" "scc_findings" {
  name    = "scc-findings"
  project = var.project_id

  message_storage_policy {
    allowed_persistence_regions = [var.region]
  }

  kms_key_name = var.kms_key_id
}

resource "google_pubsub_topic" "scc_dlq" {
  name    = "scc-findings-dlq"
  project = var.project_id

  message_storage_policy {
    allowed_persistence_regions = [var.region]
  }
}

resource "google_pubsub_topic" "falco_alerts" {
  name    = "falco-alerts"
  project = var.project_id

  message_storage_policy {
    allowed_persistence_regions = [var.region]
  }
}

resource "google_pubsub_subscription" "scc_response" {
  name    = "scc-response-sub"
  topic   = google_pubsub_topic.scc_findings.name
  project = var.project_id

  ack_deadline_seconds       = 60
  message_retention_duration = "86400s"

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.scc_dlq.id
    max_delivery_attempts = 5
  }
}

# Allow SCC to publish to the topic
resource "google_pubsub_topic_iam_member" "scc_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.scc_findings.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-scc.iam.gserviceaccount.com"
}

data "google_project" "project" {
  project_id = var.project_id
}
