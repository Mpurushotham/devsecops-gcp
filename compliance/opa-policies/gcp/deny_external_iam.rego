package gcp.deny_external_iam

import future.keywords.if
import future.keywords.in

# Deny IAM bindings with primitive roles (CIS 1.4)
deny[msg] if {
    resource := input.planned_values.root_module.resources[_]
    resource.type in {"google_project_iam_binding", "google_project_iam_member", "google_organization_iam_member"}
    resource.values.role in {"roles/owner", "roles/editor"}
    msg := sprintf("Resource '%v' must not grant primitive role '%v'", [resource.name, resource.values.role])
}

# Deny service account impersonation grants to external identities (CIS 1.5)
deny[msg] if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "google_service_account_iam_binding"
    member := resource.values.members[_]
    startswith(member, "allUsers")
    msg := sprintf("Service account IAM binding '%v' must not grant access to allUsers", [resource.name])
}

deny[msg] if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "google_service_account_iam_binding"
    member := resource.values.members[_]
    startswith(member, "allAuthenticatedUsers")
    msg := sprintf("Service account IAM binding '%v' must not grant access to allAuthenticatedUsers", [resource.name])
}
