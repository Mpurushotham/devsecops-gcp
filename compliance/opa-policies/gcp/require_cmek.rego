package gcp.require_cmek

import future.keywords.if
import future.keywords.in

# Deny GCS buckets without CMEK (CIS 5.2)
deny[msg] if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "google_storage_bucket"
    not resource.values.encryption
    msg := sprintf("GCS bucket '%v' must use customer-managed encryption (CMEK)", [resource.name])
}

deny[msg] if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "google_storage_bucket"
    resource.values.encryption
    not resource.values.encryption[0].default_kms_key_name
    msg := sprintf("GCS bucket '%v' must specify a KMS key for CMEK", [resource.name])
}

# Deny GKE clusters without database encryption (CIS 6.3)
deny[msg] if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "google_container_cluster"
    not resource.values.database_encryption
    msg := sprintf("GKE cluster '%v' must enable database encryption with CMEK", [resource.name])
}

deny[msg] if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "google_container_cluster"
    resource.values.database_encryption
    resource.values.database_encryption[0].state != "ENCRYPTED"
    msg := sprintf("GKE cluster '%v' database encryption state must be ENCRYPTED", [resource.name])
}
