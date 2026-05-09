output "keyring_id" {
  value = google_kms_key_ring.keyring.id
}

output "gke_kms_key_id" {
  value = google_kms_crypto_key.gke_secrets.id
}

output "gcs_kms_key_id" {
  value = google_kms_crypto_key.gcs.id
}

output "secret_manager_kms_key_id" {
  value = google_kms_crypto_key.secret_manager.id
}

output "artifact_registry_kms_key_id" {
  value = google_kms_crypto_key.artifact_registry.id
}

output "binauthz_attestor_name" {
  value = google_binary_authorization_attestor.build_verified.name
}

output "binauthz_kms_key_version" {
  value = data.google_kms_crypto_key_version.binauthz_key_version.id
}
