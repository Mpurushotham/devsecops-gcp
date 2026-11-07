locals {
  environment = "prod"
  region      = var.region
}

module "prod_project" {
  source = "../../modules/project-factory"

  project_name       = "devsecops-prod"
  project_id_prefix  = "devsecops-prod"
  folder_id          = var.prod_folder_id
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
    "cloudids.googleapis.com",
    "networksecurity.googleapis.com",
  ]

  budget_amount       = 5000
  budget_alert_emails = [var.notification_email]
}

# ─── Networking (prod: VPC-SC ENFORCE, no external IPs) ───────────────────────

module "networking" {
  source = "../../modules/networking"

  project_id  = module.prod_project.project_id
  region      = local.region
  environment = local.environment
  vpc_name    = "prod-vpc"

  subnet_cidr  = "10.2.0.0/20"
  pod_cidr     = "10.18.0.0/16"
  service_cidr = "10.34.0.0/20"
  master_cidr  = "172.16.2.0/28"

  # Prod: VPC-SC ENFORCED (after DRY_RUN validation in staging)
  enable_vpc_sc               = true
  vpc_sc_mode                 = "ENFORCE"
  access_policy_name          = var.access_policy_name
  vpc_sc_perimeter_resources  = [module.prod_project.project_number]
  vpc_sc_access_level_members = var.vpc_sc_allowed_members
}

# ─── Security Baseline (prod: DENY_ALL Binary Auth) ────────────────────────────

module "security_baseline" {
  source = "../../modules/security-baseline"

  project_id  = module.prod_project.project_id
  region      = local.region
  environment = local.environment

  # Prod: images MUST have a valid attestation from CI pipeline
  binary_auth_mode = "DENY_ALL"

  depends_on = [module.networking]
}

# ─── Artifact Registry ─────────────────────────────────────────────────────────

module "artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id  = module.prod_project.project_id
  region      = local.region
  environment = local.environment
  kms_key_id  = module.security_baseline.artifact_registry_kms_key_id
}

# ─── GKE (prod: private endpoint, hardened) ───────────────────────────────────

module "gke" {
  source = "../../modules/gke"

  project_id   = module.prod_project.project_id
  region       = local.region
  cluster_name = "prod-cluster"
  environment  = local.environment

  vpc_self_link      = module.networking.vpc_self_link
  subnet_self_link   = module.networking.subnet_self_link
  pod_range_name     = module.networking.pod_range_name
  service_range_name = module.networking.service_range_name

  # Prod: fully private — no public API endpoint
  # kubectl/helm commands must be routed through Cloud Build (inside VPC)
  enable_private_endpoint = true

  authorized_networks = [
    {
      cidr_block   = var.bastion_cidr
      display_name = "Bastion / jump host"
    }
  ]

  kms_key_id    = module.security_baseline.gke_kms_key_id
  node_sa_email = module.gke.node_sa_email

  system_node_min = 1
  system_node_max = 5
  app_node_min    = 2
  app_node_max    = 20

  system_node_machine_type = "e2-standard-4"
  app_node_machine_type    = "e2-standard-8"

  depends_on = [module.security_baseline]
}

# ─── SCC Automated Response ────────────────────────────────────────────────────

module "scc_response" {
  source = "../../modules/scc-response"

  project_id              = module.prod_project.project_id
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

  project_id         = module.prod_project.project_id
  org_id             = var.org_id
  region             = local.region
  environment        = local.environment
  notification_email = var.notification_email
  pagerduty_key      = var.pagerduty_key
}

# ─── Workload Identities ───────────────────────────────────────────────────────

module "workload_identities" {
  source = "../../modules/workload-identity-federation"

  project_id = module.prod_project.project_id

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
