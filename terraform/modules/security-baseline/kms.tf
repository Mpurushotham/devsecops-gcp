resource "google_kms_key_ring" "keyring" {
  name     = "${var.environment}-keyring"
  location = var.region
  project  = var.project_id
}

resource "google_kms_crypto_key" "gke_secrets" {
  name            = "gke-secrets-key"
  key_ring        = google_kms_key_ring.keyring.id
  rotation_period = var.kms_key_rotation_period
  purpose         = "ENCRYPT_DECRYPT"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_kms_crypto_key" "gcs" {
  name            = "gcs-encryption-key"
  key_ring        = google_kms_key_ring.keyring.id
  rotation_period = var.kms_key_rotation_period
  purpose         = "ENCRYPT_DECRYPT"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_kms_crypto_key" "secret_manager" {
  name            = "secret-manager-key"
  key_ring        = google_kms_key_ring.keyring.id
  rotation_period = var.kms_key_rotation_period
  purpose         = "ENCRYPT_DECRYPT"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_kms_crypto_key" "artifact_registry" {
  name            = "artifact-registry-key"
  key_ring        = google_kms_key_ring.keyring.id
  rotation_period = var.kms_key_rotation_period
  purpose         = "ENCRYPT_DECRYPT"

  lifecycle {
    prevent_destroy = true
  }
}

# Asymmetric signing key for Binary Authorization attestations
resource "google_kms_crypto_key" "binauthz_attestor" {
  name     = "binauthz-attestor-key"
  key_ring = google_kms_key_ring.keyring.id
  purpose  = "ASYMMETRIC_SIGN"

  version_template {
    algorithm        = "EC_SIGN_P256_SHA256"
    protection_level = "SOFTWARE"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Grant GKE service account access to decrypt GKE secrets key
resource "google_kms_crypto_key_iam_member" "gke_sa_kms" {
  count         = var.gke_sa_email != "" ? 1 : 0
  crypto_key_id = google_kms_crypto_key.gke_secrets.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${var.gke_sa_email}"
}

# Grant Google-managed GCS service agent access to GCS encryption key
resource "google_kms_crypto_key_iam_member" "gcs_sa_kms" {
  crypto_key_id = google_kms_crypto_key.gcs.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.project.number}@gs-project-accounts.iam.gserviceaccount.com"
}

# Grant Google-managed Artifact Registry service agent access to its encryption key
resource "google_kms_crypto_key_iam_member" "ar_sa_kms" {
  count         = var.artifact_registry_sa_email != "" ? 1 : 0
  crypto_key_id = google_kms_crypto_key.artifact_registry.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${var.artifact_registry_sa_email}"
}

data "google_project" "project" {
  project_id = var.project_id
}
