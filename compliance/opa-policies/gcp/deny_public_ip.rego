package gcp.deny_public_ip

import future.keywords.if
import future.keywords.in

# Deny GKE clusters with public endpoint enabled in prod (CIS 6.6)
deny[msg] if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "google_container_cluster"
    resource.values.private_cluster_config
    config := resource.values.private_cluster_config[_]
    config.enable_private_endpoint == false
    input.variables.environment.value == "prod"
    msg := sprintf("GKE cluster '%v' must disable the public endpoint in prod (enable_private_endpoint=true)", [resource.name])
}

# Deny GKE nodes with external IPs (CIS 6.2)
deny[msg] if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "google_container_cluster"
    resource.values.private_cluster_config
    config := resource.values.private_cluster_config[_]
    config.enable_private_nodes == false
    msg := sprintf("GKE cluster '%v' must use private nodes (enable_private_nodes=true)", [resource.name])
}

# Deny compute instances with external IPs (CIS 4.9)
deny[msg] if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "google_compute_instance"
    iface := resource.values.network_interface[_]
    count(iface.access_config) > 0
    msg := sprintf("Compute instance '%v' must not have an external IP (access_config must be empty)", [resource.name])
}

# Deny Cloud SQL instances with public IP (CIS 6.2)
deny[msg] if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "google_sql_database_instance"
    settings := resource.values.settings[_]
    ip_config := settings.ip_configuration[_]
    ip_config.ipv4_enabled == true
    msg := sprintf("Cloud SQL instance '%v' must not have a public IP (ipv4_enabled=false)", [resource.name])
}
