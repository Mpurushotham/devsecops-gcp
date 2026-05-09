# Container Analysis note used by the attestor
resource "google_container_analysis_note" "build_attestor" {
  name    = "build-verified"
  project = var.project_id

  attestation_authority {
    hint {
      human_readable_name = "Build Verified — CI pipeline scan passed"
    }
  }
}

# Attestor that CI uses to sign images after scan passes
resource "google_binary_authorization_attestor" "build_verified" {
  name    = "build-verified"
  project = var.project_id

  attestation_authority_note {
    note_reference = google_container_analysis_note.build_attestor.name

    public_keys {
      id = data.google_kms_crypto_key_version.binauthz_key_version.id
      pkix_public_key {
        public_key_pem      = data.google_kms_crypto_key_version.binauthz_key_version.public_key[0].pem
        signature_algorithm = "ECDSA_P256_SHA256"
      }
    }
  }
}

data "google_kms_crypto_key_version" "binauthz_key_version" {
  crypto_key = google_kms_crypto_key.binauthz_attestor.id
}

# Binary Authorization policy — WARN in dev/staging, DENY_ALL in prod
resource "google_binary_authorization_policy" "policy" {
  project = var.project_id

  default_admission_rule {
    evaluation_mode  = var.binary_auth_mode == "DENY_ALL" ? "REQUIRE_ATTESTATION" : "ALWAYS_ALLOW"
    enforcement_mode = var.binary_auth_mode == "DENY_ALL" ? "ENFORCED_BLOCK_AND_AUDIT_LOG" : "DRYRUN_AUDIT_LOG_ONLY"

    dynamic "require_attestations_by" {
      for_each = var.binary_auth_mode == "DENY_ALL" ? [1] : []
      content {
        attestor = google_binary_authorization_attestor.build_verified.name
      }
    }
  }

  # Always allow GKE system images
  admission_whitelist_patterns {
    name_pattern = "gcr.io/google-containers/*"
  }

  admission_whitelist_patterns {
    name_pattern = "gcr.io/google_containers/*"
  }

  admission_whitelist_patterns {
    name_pattern = "gcr.io/stackdriver-agents/*"
  }

  admission_whitelist_patterns {
    name_pattern = "gke.gcr.io/*"
  }

  admission_whitelist_patterns {
    name_pattern = "k8s.gcr.io/*"
  }

  admission_whitelist_patterns {
    name_pattern = "registry.k8s.io/*"
  }
}
