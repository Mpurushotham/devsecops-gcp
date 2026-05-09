# Phase 1: local backend — run once manually, then migrate to GCS.
# After first apply:
#   1. Uncomment the gcs backend block below
#   2. Comment out the local block
#   3. Run: terraform init -migrate-state
#   4. Verify state is in GCS, then delete the local terraform.tfstate
terraform {
  backend "local" {}

  # backend "gcs" {
  #   bucket = "<seed-project-id>-tfstate"
  #   prefix = "bootstrap"
  # }
}
