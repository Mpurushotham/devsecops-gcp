#!/usr/bin/env bash
# bootstrap.sh — Validates prerequisites before running terraform/bootstrap.
# Run from the repo root: ./scripts/bootstrap.sh

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; exit 1; }

echo "=== DevSecOps GCP Bootstrap Validator ==="

# Check required tools
for tool in terraform gcloud git pre-commit; do
  command -v "$tool" &>/dev/null && ok "$tool found" || fail "$tool is not installed"
done

# Check Terraform version
TF_VERSION=$(terraform version -json | python3 -c "import sys,json; print(json.load(sys.stdin)['terraform_version'])")
REQUIRED="1.9.0"
if python3 -c "from packaging import version; exit(0 if version.parse('$TF_VERSION') >= version.parse('$REQUIRED') else 1)" 2>/dev/null; then
  ok "Terraform $TF_VERSION >= $REQUIRED"
else
  fail "Terraform $TF_VERSION is too old — need >= $REQUIRED"
fi

# Check gcloud auth
if gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q "@"; then
  ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -1)
  ok "gcloud authenticated as $ACCOUNT"
else
  fail "Not authenticated to gcloud — run: gcloud auth application-default login"
fi

# Check terraform.tfvars exists
if [[ -f terraform/bootstrap/terraform.tfvars ]]; then
  ok "terraform/bootstrap/terraform.tfvars exists"
else
  warn "terraform/bootstrap/terraform.tfvars not found"
  echo "    → Copy and fill: cp terraform/bootstrap/terraform.tfvars.example terraform/bootstrap/terraform.tfvars"
fi

# Check .gitignore excludes tfvars
if grep -q "terraform.tfvars$" .gitignore 2>/dev/null; then
  ok ".gitignore excludes terraform.tfvars"
else
  fail "terraform.tfvars is not in .gitignore — add it before proceeding"
fi

echo ""
echo "=== Validation complete. Run: ==="
echo "  cd terraform/bootstrap && terraform init && terraform plan"
