package gcp.require_vpc_flow_logs

import future.keywords.if

# Deny subnets without VPC flow logs enabled (CIS 3.8)
deny[msg] if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "google_compute_subnetwork"
    not resource.values.log_config
    msg := sprintf("Subnet '%v' must have VPC flow logs enabled", [resource.name])
}

deny[msg] if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "google_compute_subnetwork"
    resource.values.log_config
    config := resource.values.log_config[_]
    config.flow_sampling < 0.5
    msg := sprintf("Subnet '%v' VPC flow log sampling must be >= 0.5 (got %v)", [resource.name, config.flow_sampling])
}
