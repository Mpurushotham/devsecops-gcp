variable "project_id" {
  description = "GCP project ID for networking resources"
  type        = string
}

variable "region" {
  description = "Primary GCP region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC network"
  type        = string
  default     = "main-vpc"
}

variable "subnet_cidr" {
  description = "Primary subnet CIDR block"
  type        = string
  default     = "10.0.0.0/20"
}

variable "pod_cidr" {
  description = "Secondary range CIDR for GKE pods"
  type        = string
  default     = "10.16.0.0/16"
}

variable "service_cidr" {
  description = "Secondary range CIDR for GKE services"
  type        = string
  default     = "10.32.0.0/20"
}

variable "master_cidr" {
  description = "CIDR block for GKE master nodes (must be /28)"
  type        = string
  default     = "172.16.0.0/28"
}

variable "bastion_cidr" {
  description = "CIDR of the bastion/jump host for authorized master access"
  type        = string
  default     = ""
}

variable "enable_vpc_sc" {
  description = "Whether to create VPC Service Controls perimeter"
  type        = bool
  default     = false
}

variable "vpc_sc_mode" {
  description = "VPC-SC enforcement mode: DRY_RUN or ENFORCE"
  type        = string
  default     = "DRY_RUN"
  validation {
    condition     = contains(["DRY_RUN", "ENFORCE"], var.vpc_sc_mode)
    error_message = "vpc_sc_mode must be DRY_RUN or ENFORCE"
  }
}

variable "access_policy_name" {
  description = "Access Context Manager access policy resource name"
  type        = string
  default     = ""
}

variable "vpc_sc_perimeter_resources" {
  description = "Project numbers to include in the VPC-SC perimeter"
  type        = list(string)
  default     = []
}

variable "vpc_sc_access_level_members" {
  description = "Members allowed to access resources within the VPC-SC perimeter"
  type        = list(string)
  default     = []
}

variable "nat_router_name" {
  description = "Name for the Cloud NAT router"
  type        = string
  default     = "nat-router"
}
