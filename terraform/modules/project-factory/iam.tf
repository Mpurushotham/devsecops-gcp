variable "project_iam_bindings" {
  description = "Map of role -> list of members to bind at the project level"
  type        = map(list(string))
  default     = {}
}

resource "google_project_iam_binding" "bindings" {
  for_each = var.project_iam_bindings

  project = google_project.project.project_id
  role    = each.key
  members = each.value
}
