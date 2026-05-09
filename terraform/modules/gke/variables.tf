variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for the regional GKE cluster"
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "vpc_self_link" {
  description = "VPC network self-link"
  type        = string
}

variable "subnet_self_link" {
  description = "Subnet self-link"
  type        = string
}

variable "pod_range_name" {
  description = "Secondary range name for pods"
  type        = string
  default     = "gke-pods"
}

variable "service_range_name" {
  description = "Secondary range name for services"
  type        = string
  default     = "gke-services"
}

variable "master_cidr" {
  description = "CIDR for the GKE master nodes (/28)"
  type        = string
  default     = "172.16.0.0/28"
}

variable "enable_private_endpoint" {
  description = "Whether to enable private endpoint (no public API server)"
  type        = bool
  default     = false
}

variable "authorized_networks" {
  description = "CIDR blocks authorized to access the GKE API server"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "kms_key_id" {
  description = "KMS key ID for GKE etcd encryption at rest"
  type        = string
}

variable "node_sa_email" {
  description = "Service account email for GKE node pools"
  type        = string
}

variable "system_node_machine_type" {
  description = "Machine type for the system node pool"
  type        = string
  default     = "e2-standard-4"
}

variable "app_node_machine_type" {
  description = "Machine type for the application node pool"
  type        = string
  default     = "e2-standard-4"
}

variable "system_node_min" {
  type    = number
  default = 1
}

variable "system_node_max" {
  type    = number
  default = 5
}

variable "app_node_min" {
  type    = number
  default = 0
}

variable "app_node_max" {
  type    = number
  default = 10
}
