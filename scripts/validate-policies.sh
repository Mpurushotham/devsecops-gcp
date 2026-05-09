#!/usr/bin/env bash
# validate-policies.sh — Run OPA policy tests and Terraform plan validation locally.
# Usage: ./scripts/validate-policies.sh [dev|staging|prod]

set -euo pipefail

ENV="${1:-dev}"
REPO_ROOT="$(git rev-parse --show-toplevel)"

echo "=== OPA Policy Unit Tests ==="
opa test "${REPO_ROOT}/kubernetes/gatekeeper/constraint-templates/" -v
opa test "${REPO_ROOT}/compliance/opa-policies/" -v

echo ""
echo "=== Terraform Plan OPA Check (env: ${ENV}) ==="
cd "${REPO_ROOT}/terraform/environments/${ENV}"

if [[ ! -f terraform.tfvars ]]; then
  echo "No terraform.tfvars found — skipping plan validation"
  echo "Copy terraform.tfvars.example to terraform.tfvars and fill in values"
  exit 0
fi

terraform init -input=false -no-color
terraform plan -out=tfplan.binary -input=false -no-color
terraform show -json tfplan.binary > tfplan.json

conftest test tfplan.json \
  --policy "${REPO_ROOT}/compliance/opa-policies/gcp/" \
  --output table

rm -f tfplan.binary tfplan.json

echo ""
echo "=== Done ==="
