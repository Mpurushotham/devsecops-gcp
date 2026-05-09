# Example: Slack webhook secret for SCC response notifications
resource "google_secret_manager_secret" "slack_webhook" {
  secret_id = "scc-slack-webhook-url"
  project   = var.project_id

  replication {
    user_managed {
      replicas {
        location = var.region
        customer_managed_encryption {
          kms_key_name = google_kms_crypto_key.secret_manager.id
        }
      }
    }
  }

  labels = {
    environment = var.environment
    managed-by  = "terraform"
  }
}
