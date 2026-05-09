resource "random_id" "suffix" {
  byte_length = 2
}

resource "google_project" "project" {
  name            = var.project_name
  project_id      = "${var.project_id_prefix}-${random_id.suffix.hex}"
  folder_id       = var.folder_id
  billing_account = var.billing_account_id
  deletion_policy = "PREVENT"

  labels = merge(
    {
      environment = var.environment
      managed-by  = "terraform"
    },
    var.labels
  )
}
