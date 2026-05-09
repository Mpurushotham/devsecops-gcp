resource "google_access_context_manager_access_level" "internal_users" {
  count  = var.enable_vpc_sc ? 1 : 0
  parent = "accessPolicies/${var.access_policy_name}"
  name   = "accessPolicies/${var.access_policy_name}/accessLevels/${var.environment}-internal"

  title = "${var.environment} Internal Access"

  basic {
    conditions {
      members = var.vpc_sc_access_level_members
    }
  }
}

resource "google_access_context_manager_service_perimeter" "perimeter" {
  count  = var.enable_vpc_sc ? 1 : 0
  parent = "accessPolicies/${var.access_policy_name}"
  name   = "accessPolicies/${var.access_policy_name}/servicePerimeters/${var.environment}-perimeter"

  title = "${var.environment} Service Perimeter"

  # Start with DRY_RUN — switch to ENFORCE after observing violations for 1 week
  perimeter_type = "PERIMETER_TYPE_REGULAR"

  spec {
    resources = [for p in var.vpc_sc_perimeter_resources : "projects/${p}"]

    restricted_services = [
      "storage.googleapis.com",
      "bigquery.googleapis.com",
      "secretmanager.googleapis.com",
      "cloudkms.googleapis.com",
      "containerregistry.googleapis.com",
      "artifactregistry.googleapis.com",
    ]

    access_levels = var.enable_vpc_sc ? [google_access_context_manager_access_level.internal_users[0].name] : []

    vpc_accessible_services {
      enable_restriction = true
      allowed_services   = ["RESTRICTED-SERVICES"]
    }
  }

  # Use spec (DRY_RUN) vs status (ENFORCE) — controlled by the use_explicit_dry_run_spec field
  use_explicit_dry_run_spec = var.vpc_sc_mode == "DRY_RUN"
}
