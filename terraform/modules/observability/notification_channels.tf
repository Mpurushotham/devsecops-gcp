resource "google_monitoring_notification_channel" "email" {
  project      = var.project_id
  display_name = "Security Team Email"
  type         = "email"

  labels = {
    email_address = var.notification_email
  }
}

resource "google_monitoring_notification_channel" "pagerduty" {
  count        = var.pagerduty_key != "" ? 1 : 0
  project      = var.project_id
  display_name = "PagerDuty — On-call"
  type         = "pagerduty"

  sensitive_labels {
    service_key = var.pagerduty_key
  }
}
