output "scc_pubsub_topic" {
  value = google_pubsub_topic.scc_findings.id
}

output "falco_pubsub_topic" {
  value = google_pubsub_topic.falco_alerts.id
}

output "scc_responder_function_name" {
  value = google_cloudfunctions2_function.scc_responder.name
}
