data "google_project" "project" {
  project_id = var.project_id
}

# Create a GCP SA per workload
resource "google_service_account" "workload_sa" {
  for_each = var.workload_identities

  project      = var.project_id
  account_id   = substr(replace(each.key, "_", "-"), 0, 30)
  display_name = "Workload Identity SA — ${each.key}"
  description  = "GCP SA for Kubernetes workload: ${each.value.namespace}/${each.value.ksa_name}"
}

# Bind Kubernetes SA → GCP SA via Workload Identity
resource "google_service_account_iam_member" "workload_identity_binding" {
  for_each = var.workload_identities

  service_account_id = google_service_account.workload_sa[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${each.value.namespace}/${each.value.ksa_name}]"
}

# Grant GCP SA the required roles
resource "google_project_iam_member" "workload_sa_roles" {
  for_each = {
    for pair in flatten([
      for name, cfg in var.workload_identities : [
        for role in cfg.gcp_roles : {
          key  = "${name}--${role}"
          name = name
          role = role
        }
      ]
    ]) : pair.key => pair
  }

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.workload_sa[each.value.name].email}"
}
