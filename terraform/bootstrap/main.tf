locals {
  seed_project_id = "${var.seed_project_name}-${random_id.suffix.hex}"
}

resource "random_id" "suffix" {
  byte_length = 2
}

# ─── Seed Project ───────────────────────────────────────────────────────────

resource "google_project" "seed" {
  name            = var.seed_project_name
  project_id      = local.seed_project_id
  org_id          = var.org_id
  billing_account = var.billing_account_id

  deletion_policy = "PREVENT"

  auto_create_network = false

  labels = {
    environment = "bootstrap"
    managed-by  = "terraform"
  }
}

resource "google_project_service" "seed_apis" {
  for_each = toset([
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "storage.googleapis.com",
    "cloudbilling.googleapis.com",
    "secretmanager.googleapis.com",
    "logging.googleapis.com",
  ])

  project            = google_project.seed.project_id
  service            = each.value
  disable_on_destroy = false
}

# ─── Terraform State Bucket ─────────────────────────────────────────────────

resource "google_storage_bucket" "tfstate" {
  name          = "${local.seed_project_id}-tfstate"
  project       = google_project.seed.project_id
  location      = var.region
  force_destroy = false

  versioning {
    enabled = true
  }

  uniform_bucket_level_access = true

  public_access_prevention = "enforced"

  lifecycle_rule {
    condition {
      num_newer_versions = 10
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.seed_apis]
}

# ─── Terraform Service Accounts ─────────────────────────────────────────────

resource "google_service_account" "terraform_plan" {
  project      = google_project.seed.project_id
  account_id   = var.terraform_sa_name
  display_name = "GitHub Actions — Terraform Plan"
  description  = "Used by GitHub Actions for terraform plan on PRs. Read-only GCP access."
}

resource "google_service_account" "terraform_apply" {
  project      = google_project.seed.project_id
  account_id   = var.terraform_apply_sa_name
  display_name = "GitHub Actions — Terraform Apply"
  description  = "Used by GitHub Actions for terraform apply on main branch only."
}

resource "google_service_account" "image_push" {
  project      = google_project.seed.project_id
  account_id   = var.image_push_sa_name
  display_name = "GitHub Actions — Image Push"
  description  = "Used by GitHub Actions to push images to Artifact Registry and create Binary Auth attestations."
}

resource "google_service_account" "prowler" {
  project      = google_project.seed.project_id
  account_id   = var.prowler_sa_name
  display_name = "GitHub Actions — Prowler"
  description  = "Read-only SA for Prowler CIS/SOC2 compliance scanning."
}

# ─── State Bucket IAM ────────────────────────────────────────────────────────

resource "google_storage_bucket_iam_member" "tfstate_plan" {
  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.terraform_plan.email}"
}

resource "google_storage_bucket_iam_member" "tfstate_apply" {
  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.terraform_apply.email}"
}

# ─── Workload Identity Federation ───────────────────────────────────────────

resource "google_iam_workload_identity_pool" "github" {
  project                   = google_project.seed.project_id
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions Pool"
  description               = "WIF pool for GitHub Actions OIDC tokens"

  depends_on = [google_project_service.seed_apis]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = google_project.seed.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Actions OIDC Provider"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.ref"              = "assertion.ref"
    "attribute.workflow"         = "assertion.workflow"
  }

  # Restrict to the exact org/repo — prevents other repos from impersonating these SAs
  attribute_condition = "assertion.repository_owner == '${var.github_org}' && assertion.repository == '${var.github_org}/${var.github_repo}'"
}

# ─── WIF SA Bindings — Plan SA (any branch, PR or push) ─────────────────────

resource "google_service_account_iam_binding" "terraform_plan_wif" {
  service_account_id = google_service_account.terraform_plan.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_org}/${var.github_repo}",
  ]
}

# Apply SA — restricted to main branch via attribute condition in a separate provider
resource "google_iam_workload_identity_pool_provider" "github_main" {
  project                            = google_project.seed.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-main-provider"
  display_name                       = "GitHub Actions — main branch only"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.ref"              = "assertion.ref"
  }

  # Only tokens from main branch can impersonate the apply SA
  attribute_condition = "assertion.repository_owner == '${var.github_org}' && assertion.repository == '${var.github_org}/${var.github_repo}' && assertion.ref == 'refs/heads/main'"
}

resource "google_service_account_iam_binding" "terraform_apply_wif" {
  service_account_id = google_service_account.terraform_apply.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_org}/${var.github_repo}",
  ]
}

resource "google_service_account_iam_binding" "image_push_wif" {
  service_account_id = google_service_account.image_push.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_org}/${var.github_repo}",
  ]
}

resource "google_service_account_iam_binding" "prowler_wif" {
  service_account_id = google_service_account.prowler.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_org}/${var.github_repo}",
  ]
}

# ─── Org-level IAM for bootstrap SAs ────────────────────────────────────────
# These are temporarily elevated permissions needed during bootstrap only.
# Revoke roles/resourcemanager.organizationAdmin and roles/billing.admin
# from terraform_apply SA after Phase 1 is complete.

resource "google_organization_iam_member" "terraform_apply_folder_admin" {
  org_id = var.org_id
  role   = "roles/resourcemanager.folderAdmin"
  member = "serviceAccount:${google_service_account.terraform_apply.email}"
}

resource "google_organization_iam_member" "terraform_apply_project_creator" {
  org_id = var.org_id
  role   = "roles/resourcemanager.projectCreator"
  member = "serviceAccount:${google_service_account.terraform_apply.email}"
}

resource "google_organization_iam_member" "terraform_apply_org_policy_admin" {
  org_id = var.org_id
  role   = "roles/orgpolicy.policyAdmin"
  member = "serviceAccount:${google_service_account.terraform_apply.email}"
}

resource "google_organization_iam_member" "terraform_apply_scc_admin" {
  org_id = var.org_id
  role   = "roles/securitycenter.admin"
  member = "serviceAccount:${google_service_account.terraform_apply.email}"
}

resource "google_billing_account_iam_member" "terraform_apply_billing_user" {
  billing_account_id = var.billing_account_id
  role               = "roles/billing.user"
  member             = "serviceAccount:${google_service_account.terraform_apply.email}"
}

# Prowler needs broad read access for compliance scanning
resource "google_organization_iam_member" "prowler_viewer" {
  org_id = var.org_id
  role   = "roles/viewer"
  member = "serviceAccount:${google_service_account.prowler.email}"
}

resource "google_organization_iam_member" "prowler_security_reviewer" {
  org_id = var.org_id
  role   = "roles/iam.securityReviewer"
  member = "serviceAccount:${google_service_account.prowler.email}"
}
