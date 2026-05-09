locals {
  node_config = {
    image_type      = "COS_CONTAINERD"
    disk_type       = "pd-ssd"
    disk_size_gb    = 100
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    service_account = var.node_sa_email

    metadata = {
      # Block access to legacy GCE metadata endpoints
      disable-legacy-endpoints = "true"
    }

    shielded_instance_config = {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config = {
      # Required for Workload Identity — expose GKE metadata server, not GCE metadata
      mode = "GKE_METADATA"
    }
  }
}

# System node pool — runs kube-system, monitoring, security tooling
resource "google_container_node_pool" "system" {
  provider = google-beta

  name     = "system-pool"
  cluster  = google_container_cluster.primary.name
  location = var.region
  project  = var.project_id

  node_count = var.system_node_min

  autoscaling {
    min_node_count = var.system_node_min
    max_node_count = var.system_node_max
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
    strategy        = "SURGE"
  }

  node_config {
    machine_type    = var.system_node_machine_type
    image_type      = local.node_config.image_type
    disk_type       = local.node_config.disk_type
    disk_size_gb    = local.node_config.disk_size_gb
    oauth_scopes    = local.node_config.oauth_scopes
    service_account = local.node_config.service_account

    metadata = local.node_config.metadata

    shielded_instance_config {
      enable_secure_boot          = local.node_config.shielded_instance_config.enable_secure_boot
      enable_integrity_monitoring = local.node_config.shielded_instance_config.enable_integrity_monitoring
    }

    workload_metadata_config {
      mode = local.node_config.workload_metadata_config.mode
    }

    labels = {
      node-pool   = "system"
      environment = var.environment
    }

    taint {
      key    = "node-pool"
      value  = "system"
      effect = "NO_SCHEDULE"
    }
  }
}

# Application node pool — runs workloads; can scale to zero
resource "google_container_node_pool" "application" {
  provider = google-beta

  name     = "application-pool"
  cluster  = google_container_cluster.primary.name
  location = var.region
  project  = var.project_id

  autoscaling {
    min_node_count = var.app_node_min
    max_node_count = var.app_node_max
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 2
    max_unavailable = 0
    strategy        = "SURGE"
  }

  node_config {
    machine_type    = var.app_node_machine_type
    image_type      = local.node_config.image_type
    disk_type       = local.node_config.disk_type
    disk_size_gb    = local.node_config.disk_size_gb
    oauth_scopes    = local.node_config.oauth_scopes
    service_account = local.node_config.service_account

    metadata = local.node_config.metadata

    shielded_instance_config {
      enable_secure_boot          = local.node_config.shielded_instance_config.enable_secure_boot
      enable_integrity_monitoring = local.node_config.shielded_instance_config.enable_integrity_monitoring
    }

    workload_metadata_config {
      mode = local.node_config.workload_metadata_config.mode
    }

    labels = {
      node-pool   = "application"
      environment = var.environment
    }
  }
}
