locals {
  environment = "dev"
  region      = var.region
}

# ─── Projects ─────────────────────────────────────────────────────────────────

module "dev_project" {
  source = "../../modules/project-factory"

  project_name       = "devsecops-dev"
  project_id_prefix  = "devsecops-dev"
  folder_id          = var.dev_folder_id
  billing_account_id = var.billing_account_id
  environment        = local.environment

  activate_apis = [
    "container.googleapis.com",
    "containeranalysis.googleapis.com",
    "binaryauthorization.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudfunctions.googleapis.com",
    "pubsub.googleapis.com",
    "eventarc.googleapis.com",
    "securitycenter.googleapis.com",
    "bigquery.googleapis.com",
    "cloudbuild.googleapis.com",
  ]

  budget_amount       = 500
  budget_alert_emails = [var.notification_email]
}

module "security_project" {
  source = "../../modules/project-factory"

  project_name       = "devsecops-security"
  project_id_prefix  = "devsecops-security"
  folder_id          = var.security_folder_id
  billing_account_id = var.billing_account_id
  environment        = "security"

  activate_apis = [
    "securitycenter.googleapis.com",
    "pubsub.googleapis.com",
    "cloudfunctions.googleapis.com",
    "eventarc.googleapis.com",
    "bigquery.googleapis.com",
  ]
}

# ─── Networking ────────────────────────────────────────────────────────────────

module "networking" {
  source = "../../modules/networking"

  project_id  = module.dev_project.project_id
  region      = local.region
  environment = local.environment
  vpc_name    = "dev-vpc"

  subnet_cidr  = "10.0.0.0/20"
  pod_cidr     = "10.16.0.0/16"
  service_cidr = "10.32.0.0/20"
  master_cidr  = "172.16.0.0/28"

  # Dev: VPC-SC in DRY_RUN mode, start observing violations
  enable_vpc_sc = false
}

# ─── Security Baseline ─────────────────────────────────────────────────────────

module "security_baseline" {
  source = "../../modules/security-baseline"

  project_id  = module.dev_project.project_id
  region      = local.region
  environment = local.environment

  # Dev uses WARN mode — images that fail attestation get a warning but are still admitted
  binary_auth_mode = "WARN"

  depends_on = [module.networking]
}

# ─── Artifact Registry ─────────────────────────────────────────────────────────

module "artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id  = module.dev_project.project_id
  region      = local.region
  environment = local.environment
  kms_key_id  = module.security_baseline.artifact_registry_kms_key_id
}

# ─── GKE ───────────────────────────────────────────────────────────────────────

module "gke" {
  source = "../../modules/gke"

  project_id   = module.dev_project.project_id
  region       = local.region
  cluster_name = "dev-cluster"
  environment  = local.environment

  vpc_self_link      = module.networking.vpc_self_link
  subnet_self_link   = module.networking.subnet_self_link
  pod_range_name     = module.networking.pod_range_name
  service_range_name = module.networking.service_range_name

  # Dev: public endpoint allowed for easier access
  enable_private_endpoint = false

  authorized_networks = [
    {
      cidr_block   = "0.0.0.0/0"
      display_name = "all (dev only)"
    }
  ]

  kms_key_id    = module.security_baseline.gke_kms_key_id
  node_sa_email = module.gke.node_sa_email

  app_node_min = 0
  app_node_max = 5

  depends_on = [module.security_baseline]
}

# ─── SCC Automated Response ────────────────────────────────────────────────────

module "scc_response" {
  source = "../../modules/scc-response"

  project_id              = module.security_project.project_id
  region                  = local.region
  org_id                  = var.org_id
  kms_key_id              = module.security_baseline.gke_kms_key_id
  function_source_bucket  = var.function_source_bucket
  function_source_object  = "scc-auto-response.zip"
  slack_webhook_secret_id = "scc-slack-webhook-url"
}

# ─── Observability ─────────────────────────────────────────────────────────────

module "observability" {
  source = "../../modules/observability"

  project_id         = module.security_project.project_id
  org_id             = var.org_id
  region             = local.region
  environment        = local.environment
  notification_email = var.notification_email
}

# ─── Workload Identities ───────────────────────────────────────────────────────

module "workload_identities" {
  source = "../../modules/workload-identity-federation"

  project_id = module.dev_project.project_id

  workload_identities = {
    "app-backend" = {
      namespace = "app"
      ksa_name  = "app-backend"
      gcp_roles = ["roles/secretmanager.secretAccessor"]
    }
    "falco-sidekick" = {
      namespace = "falco-system"
      ksa_name  = "falco-sidekick"
      gcp_roles = ["roles/pubsub.publisher"]
    }
  }
}
