locals {
  environment = "staging"
  region      = var.region
}

module "staging_project" {
  source = "../../modules/project-factory"

  project_name       = "devsecops-staging"
  project_id_prefix  = "devsecops-staging"
  folder_id          = var.staging_folder_id
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

  budget_amount       = 1000
  budget_alert_emails = [var.notification_email]
}

module "networking" {
  source = "../../modules/networking"

  project_id  = module.staging_project.project_id
  region      = local.region
  environment = local.environment
  vpc_name    = "staging-vpc"

  subnet_cidr  = "10.1.0.0/20"
  pod_cidr     = "10.17.0.0/16"
  service_cidr = "10.33.0.0/20"
  master_cidr  = "172.16.1.0/28"

  # Staging: enable VPC-SC in DRY_RUN
  enable_vpc_sc = true
  vpc_sc_mode   = "DRY_RUN"
  access_policy_name = var.access_policy_name
  vpc_sc_perimeter_resources = [module.staging_project.project_number]
}

module "security_baseline" {
  source = "../../modules/security-baseline"

  project_id   = module.staging_project.project_id
  region       = local.region
  environment  = local.environment
  binary_auth_mode = "WARN"

  depends_on = [module.networking]
}

module "artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id  = module.staging_project.project_id
  region      = local.region
  environment = local.environment
  kms_key_id  = module.security_baseline.artifact_registry_kms_key_id
}

module "gke" {
  source = "../../modules/gke"

  project_id   = module.staging_project.project_id
  region       = local.region
  cluster_name = "staging-cluster"
  environment  = local.environment

  vpc_self_link      = module.networking.vpc_self_link
  subnet_self_link   = module.networking.subnet_self_link
  pod_range_name     = module.networking.pod_range_name
  service_range_name = module.networking.service_range_name

  # Staging: public endpoint allowed for CI tooling
  enable_private_endpoint = false

  authorized_networks = [
    {
      cidr_block   = "0.0.0.0/0"
      display_name = "all (staging only)"
    }
  ]

  kms_key_id    = module.security_baseline.gke_kms_key_id
  node_sa_email = module.gke.node_sa_email

  depends_on = [module.security_baseline]
}

module "scc_response" {
  source = "../../modules/scc-response"

  project_id              = module.staging_project.project_id
  region                  = local.region
  org_id                  = var.org_id
  kms_key_id              = module.security_baseline.gke_kms_key_id
  function_source_bucket  = var.function_source_bucket
  function_source_object  = "scc-auto-response.zip"
  slack_webhook_secret_id = "scc-slack-webhook-url"
}

module "observability" {
  source = "../../modules/observability"

  project_id         = module.staging_project.project_id
  org_id             = var.org_id
  region             = local.region
  environment        = local.environment
  notification_email = var.notification_email
}

module "workload_identities" {
  source = "../../modules/workload-identity-federation"

  project_id = module.staging_project.project_id

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
