output "bq_sink_writer_identity" {
  description = "Service account identity for the BigQuery log sink — grant bigquery.dataEditor"
  value       = google_logging_organization_sink.bq_audit.writer_identity
}

output "gcs_sink_writer_identity" {
  description = "Service account identity for the GCS archive sink — grant storage.objectCreator"
  value       = google_logging_organization_sink.gcs_archive.writer_identity
}
