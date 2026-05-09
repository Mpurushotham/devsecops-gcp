# SCC notification config — routes ALL findings to a Pub/Sub topic for automated response
resource "google_scc_notification_config" "all_findings" {
  config_id    = "all-findings-to-pubsub"
  organization = var.org_id
  description  = "Route all SCC findings to Pub/Sub for automated response pipeline"
  pubsub_topic = var.scc_pubsub_topic

  streaming_config {
    # Empty filter = ALL findings
    filter = ""
  }
}

# Separate notification for CRITICAL/HIGH only — used for PagerDuty/on-call alerting
resource "google_scc_notification_config" "critical_findings" {
  config_id    = "critical-findings-alert"
  organization = var.org_id
  description  = "Route CRITICAL and HIGH severity SCC findings to Pub/Sub for immediate alerting"
  pubsub_topic = var.scc_pubsub_topic

  streaming_config {
    filter = "severity=\"CRITICAL\" OR severity=\"HIGH\""
  }
}

# Mute low-priority informational findings in dev/test to reduce noise
resource "google_scc_mute_config" "dev_low_severity" {
  mute_config_id = "mute-dev-informational"
  parent         = "organizations/${var.org_id}"
  filter         = "severity=\"LOW\" OR severity=\"INFORMATIONAL\""
  description    = "Mute low/informational severity findings org-wide to reduce noise in dashboards"
  type           = "STATIC"
}
