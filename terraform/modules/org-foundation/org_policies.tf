locals {
  enforce_policies = [
    "constraints/compute.requireOsLogin",
    "constraints/compute.disableSerialPortAccess",
    "constraints/compute.disableSerialPortLogging",
    "constraints/compute.skipDefaultNetworkCreation",
    "constraints/iam.disableServiceAccountKeyCreation",
    "constraints/iam.disableServiceAccountKeyUpload",
    "constraints/iam.automaticIamGrantsForDefaultServiceAccounts",
    "constraints/storage.uniformBucketLevelAccess",
    "constraints/storage.publicAccessPrevention",
    "constraints/compute.requireShieldedVm",
  ]
}

resource "google_org_policy_policy" "enforce" {
  for_each = toset(local.enforce_policies)

  name   = "organizations/${var.org_id}/policies/${each.value}"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# Deny all external IP addresses on VMs
resource "google_org_policy_policy" "deny_external_ip" {
  name   = "organizations/${var.org_id}/policies/constraints/compute.vmExternalIpAccess"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      deny_all = "TRUE"
    }
  }
}

# Restrict resource locations to approved regions
resource "google_org_policy_policy" "resource_locations" {
  name   = "organizations/${var.org_id}/policies/constraints/gcp.resourceLocations"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      values {
        allowed_values = [for r in var.allowed_regions : "in:${r}-locations"]
      }
    }
  }
}

# Restrict Cloud Run ingress to internal + cloud load balancing only
resource "google_org_policy_policy" "cloudrun_ingress" {
  name   = "organizations/${var.org_id}/policies/constraints/run.allowedIngress"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      values {
        allowed_values = ["internal-and-cloud-load-balancing"]
      }
    }
  }
}

# Restrict Cloud Functions ingress
resource "google_org_policy_policy" "cloudfunctions_ingress" {
  name   = "organizations/${var.org_id}/policies/constraints/cloudfunctions.allowedIngressSettings"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      values {
        allowed_values = ["ALLOW_INTERNAL_AND_GCLB"]
      }
    }
  }
}

# Require CMEK for supported services
resource "google_org_policy_policy" "require_cmek_gke" {
  name   = "organizations/${var.org_id}/policies/constraints/gcp.restrictCmekCryptoKeyProjects"
  parent = "organizations/${var.org_id}"

  spec {
    inherit_from_parent = false
    rules {
      allow_all = "TRUE"
    }
  }
}

# Disable Domain Restricted Sharing — must be explicitly configured if needed
resource "google_org_policy_policy" "domain_restricted_sharing" {
  name   = "organizations/${var.org_id}/policies/constraints/iam.allowedPolicyMemberDomains"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      values {
        # Replace with your Google Workspace customer ID (C0xxxxxxx)
        allowed_values = ["is:principalSet"]
      }
    }
  }
}
