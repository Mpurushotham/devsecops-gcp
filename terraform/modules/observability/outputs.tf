output "audit_bq_dataset_id" {
  value = google_bigquery_dataset.audit_logs.dataset_id
}

output "log_archive_bucket" {
  value = google_storage_bucket.log_archive.name
}

output "email_notification_channel_id" {
  value = google_monitoring_notification_channel.email.id
}
