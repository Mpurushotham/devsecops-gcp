variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "workload_identities" {
  description = "Map of workload identity configurations: app name -> {namespace, ksa_name, gcp_roles}"
  type = map(object({
    namespace = string
    ksa_name  = string
    gcp_roles = list(string)
  }))
  default = {}
}
