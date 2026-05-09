package gcp.require_os_login

import future.keywords.if

# Deny compute instances without OS Login enabled (CIS 4.4)
deny[msg] if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "google_compute_instance"
    metadata := resource.values.metadata
    not metadata["enable-oslogin"]
    msg := sprintf("Compute instance '%v' must enable OS Login (metadata enable-oslogin=TRUE)", [resource.name])
}

deny[msg] if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "google_compute_instance"
    metadata := resource.values.metadata
    metadata["enable-oslogin"] != "TRUE"
    msg := sprintf("Compute instance '%v' OS Login must be TRUE, got '%v'", [resource.name, metadata["enable-oslogin"]])
}

# Deny GKE node pools without legacy metadata endpoints disabled (CIS 6.4)
deny[msg] if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "google_container_node_pool"
    node_config := resource.values.node_config[_]
    metadata := node_config.metadata
    metadata["disable-legacy-endpoints"] != "true"
    msg := sprintf("GKE node pool '%v' must set metadata disable-legacy-endpoints=true", [resource.name])
}
