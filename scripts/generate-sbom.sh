#!/usr/bin/env bash
# generate-sbom.sh — Generate Software Bill of Materials for container images and filesystem.
# Usage: ./scripts/generate-sbom.sh IMAGE_REF [OUTPUT_DIR]
# Requires: syft, grype (optional for vuln scan), cosign (optional for attestation)

set -euo pipefail

IMAGE_REF="${1:?Usage: $0 IMAGE_REF [OUTPUT_DIR]}"
OUTPUT_DIR="${2:-./compliance/reports}"
TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
IMAGE_SLUG=$(echo "${IMAGE_REF}" | tr '/:' '-')

mkdir -p "${OUTPUT_DIR}/sbom"

echo "=== SBOM Generation: ${IMAGE_REF} ==="
echo "Output directory: ${OUTPUT_DIR}/sbom"
echo ""

# --- Filesystem SBOM (repo-level) ---
echo "[1/4] Generating filesystem SBOM (repo)..."
syft dir:. \
  --output spdx-json="${OUTPUT_DIR}/sbom/repo-sbom-${TIMESTAMP}.spdx.json" \
  --output cyclonedx-json="${OUTPUT_DIR}/sbom/repo-sbom-${TIMESTAMP}.cdx.json" \
  --exclude './.git' \
  --exclude './.terraform' \
  --exclude './compliance/reports'
echo "  -> repo-sbom-${TIMESTAMP}.spdx.json"
echo "  -> repo-sbom-${TIMESTAMP}.cdx.json"

# --- Container Image SBOM ---
echo ""
echo "[2/4] Generating container image SBOM: ${IMAGE_REF}..."
syft "${IMAGE_REF}" \
  --output spdx-json="${OUTPUT_DIR}/sbom/image-sbom-${IMAGE_SLUG}-${TIMESTAMP}.spdx.json" \
  --output cyclonedx-json="${OUTPUT_DIR}/sbom/image-sbom-${IMAGE_SLUG}-${TIMESTAMP}.cdx.json" \
  --output table
echo "  -> image-sbom-${IMAGE_SLUG}-${TIMESTAMP}.spdx.json"
echo "  -> image-sbom-${IMAGE_SLUG}-${TIMESTAMP}.cdx.json"

# --- Vulnerability scan against SBOM ---
echo ""
echo "[3/4] Scanning SBOM for vulnerabilities..."
if command -v grype &>/dev/null; then
  grype "sbom:${OUTPUT_DIR}/sbom/image-sbom-${IMAGE_SLUG}-${TIMESTAMP}.spdx.json" \
    --output sarif \
    --file "${OUTPUT_DIR}/sbom/vuln-${IMAGE_SLUG}-${TIMESTAMP}.sarif" \
    --fail-on high || {
    echo "  [WARN] High/Critical vulnerabilities found — review ${OUTPUT_DIR}/sbom/vuln-${IMAGE_SLUG}-${TIMESTAMP}.sarif"
  }
  echo "  -> vuln-${IMAGE_SLUG}-${TIMESTAMP}.sarif"
else
  echo "  [SKIP] grype not found — install with: curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh"
fi

# --- Cosign SBOM attestation (requires KMS key or keyless) ---
echo ""
echo "[4/4] Attesting SBOM (requires cosign + image in registry)..."
if command -v cosign &>/dev/null; then
  if [[ -n "${COSIGN_KEY_REF:-}" ]]; then
    cosign attest \
      --type spdxjson \
      --predicate "${OUTPUT_DIR}/sbom/image-sbom-${IMAGE_SLUG}-${TIMESTAMP}.spdx.json" \
      --key "${COSIGN_KEY_REF}" \
      "${IMAGE_REF}" \
      && echo "  -> SBOM attestation pushed to registry" \
      || echo "  [WARN] Attestation failed — image may not be in registry yet"
  else
    echo "  [SKIP] Set COSIGN_KEY_REF=gcpkms://... or a local key path to attest"
  fi
else
  echo "  [SKIP] cosign not found — install with: brew install cosign"
fi

echo ""
echo "=== SBOM generation complete ==="
echo "Files written to: ${OUTPUT_DIR}/sbom/"
ls -lh "${OUTPUT_DIR}/sbom/" | grep "${TIMESTAMP}" || true
