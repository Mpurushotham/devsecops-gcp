variable "iam_bindings" {
  description = "Map of role to list of members for project-level IAM"
  type        = map(list(string))
  default     = {}
}

resource "google_project_iam_binding" "security_bindings" {
  for_each = var.iam_bindings

  project = var.project_id
  role    = each.key
  members = each.value
}
