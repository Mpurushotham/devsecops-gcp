resource "google_folder" "bootstrap" {
  display_name = "bootstrap"
  parent       = "organizations/${var.org_id}"
}

resource "google_folder" "common" {
  display_name = "common"
  parent       = "organizations/${var.org_id}"
}

resource "google_folder" "environments" {
  display_name = "environments"
  parent       = "organizations/${var.org_id}"
}

resource "google_folder" "dev" {
  display_name = "dev"
  parent       = google_folder.environments.name
}

resource "google_folder" "staging" {
  display_name = "staging"
  parent       = google_folder.environments.name
}

resource "google_folder" "prod" {
  display_name = "prod"
  parent       = google_folder.environments.name
}

resource "google_folder" "security" {
  display_name = "security"
  parent       = "organizations/${var.org_id}"
}

resource "google_folder" "networking" {
  display_name = "networking"
  parent       = "organizations/${var.org_id}"
}
