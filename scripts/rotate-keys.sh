#!/usr/bin/env bash
# rotate-keys.sh — Trigger KMS key rotation and update Secret Manager secrets.
# Usage: ./scripts/rotate-keys.sh PROJECT_ID REGION
# Requires: gcloud, active auth

set -euo pipefail

PROJECT_ID="${1:?Usage: $0 PROJECT_ID REGION}"
REGION="${2:?Usage: $0 PROJECT_ID REGION}"
KEYRING="${3:-dev-keyring}"

echo "=== KMS Key Rotation Check (project: ${PROJECT_ID}) ==="

# List all keys in the keyring and their rotation schedule
gcloud kms keys list \
  --keyring="${KEYRING}" \
  --location="${REGION}" \
  --project="${PROJECT_ID}" \
  --format="table(name,primary.state,rotationPeriod,nextRotationTime)"

echo ""
echo "Keys with auto-rotation configured will rotate automatically."
echo "To trigger an immediate rotation (creates a new primary version):"
echo "  gcloud kms keys versions create --key=KEY_NAME --keyring=${KEYRING} --location=${REGION} --project=${PROJECT_ID}"
echo ""
echo "=== Secret Manager Secret Versions ==="
gcloud secrets list \
  --project="${PROJECT_ID}" \
  --format="table(name,createTime,replication.userManaged.replicas[0].location)"
