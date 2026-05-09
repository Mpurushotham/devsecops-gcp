terraform {
  backend "gcs" {
    # Set bucket to the tfstate bucket name from bootstrap outputs
    bucket = "REPLACE_WITH_TFSTATE_BUCKET"
    prefix = "environments/staging"
  }
}
