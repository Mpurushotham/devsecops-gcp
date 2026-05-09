# Key Rotation Runbook

## Overview

This runbook covers manual and automated key rotation for KMS keys and Secret Manager secrets in the DevSecOps platform.

## Automated Rotation (KMS)

KMS keys are configured with a **90-day rotation period** via `rotation_period = "7776000s"` in `terraform/modules/security-baseline/kms.tf`. GCP automatically creates a new key version and promotes it to primary. No action is required for encryption/decryption — existing ciphertexts remain decryptable with prior versions.

**Keys with auto-rotation:**
| Key | Keyring | Purpose |
|---|---|---|
| `gke-secrets-key` | `{env}-keyring` | GKE etcd encryption |
| `gcs-key` | `{env}-keyring` | GCS bucket CMEK |
| `secret-manager-key` | `{env}-keyring` | Secret Manager CMEK |
| `artifact-registry-key` | `{env}-keyring` | Artifact Registry CMEK |

**Exception:** `binauthz-attestor-key` uses `EC_SIGN_P256_SHA256` for asymmetric signing — it has no auto-rotation (asymmetric keys require manual rotation and attestor update).

---

## Viewing Rotation Status

```bash
./scripts/rotate-keys.sh PROJECT_ID REGION [KEYRING]
```

Example:
```bash
./scripts/rotate-keys.sh my-dev-project us-central1 dev-keyring
```

To check a specific key:
```bash
gcloud kms keys describe gke-secrets-key \
  --keyring=dev-keyring \
  --location=us-central1 \
  --project=PROJECT_ID \
  --format="yaml(primary.state,rotationPeriod,nextRotationTime)"
```

---

## Manual KMS Key Version Rotation

Use when an immediate rotation is required (e.g., suspected key compromise).

```bash
# Create a new primary key version (triggers immediate rotation)
gcloud kms keys versions create \
  --key=gke-secrets-key \
  --keyring=dev-keyring \
  --location=us-central1 \
  --project=PROJECT_ID

# Verify the new version is primary
gcloud kms keys versions list \
  --key=gke-secrets-key \
  --keyring=dev-keyring \
  --location=us-central1 \
  --project=PROJECT_ID
```

After rotation, disable old key versions (do not destroy — existing ciphertexts need them):
```bash
gcloud kms keys versions disable VERSION_NUMBER \
  --key=gke-secrets-key \
  --keyring=dev-keyring \
  --location=us-central1 \
  --project=PROJECT_ID
```

---

## Binary Authorization Attestor Key Rotation

The `binauthz-attestor-key` requires manual rotation and attestor update since it uses an asymmetric signing key.

1. **Create a new key version:**
```bash
gcloud kms keys versions create \
  --key=binauthz-attestor-key \
  --keyring=KEYRING \
  --location=REGION \
  --project=PROJECT_ID
```

2. **Get the new public key:**
```bash
NEW_VERSION=$(gcloud kms keys versions list \
  --key=binauthz-attestor-key \
  --keyring=KEYRING \
  --location=REGION \
  --project=PROJECT_ID \
  --filter="state=ENABLED" \
  --sort-by="~name" \
  --format="value(name)" | head -1)

gcloud kms keys versions get-public-key "${NEW_VERSION}" \
  --output-file=/tmp/new-attestor-key.pem
```

3. **Add the new public key to the attestor:**
```bash
gcloud container binauthz attestors public-keys add \
  --attestor=ATTESTOR_NAME \
  --project=PROJECT_ID \
  --pgp-public-key-file=/tmp/new-attestor-key.pem
```

4. **Remove the old public key** (get its ID first):
```bash
gcloud container binauthz attestors public-keys remove OLD_KEY_ID \
  --attestor=ATTESTOR_NAME \
  --project=PROJECT_ID
```

5. **Update Terraform** to reference the new version in `binary_authorization.tf` to keep state in sync.

---

## Secret Manager Secret Rotation

Secrets do not auto-rotate — applications must implement rotation logic or a Cloud Scheduler job must trigger it.

**List current secrets and their versions:**
```bash
gcloud secrets list --project=PROJECT_ID
gcloud secrets versions list SECRET_NAME --project=PROJECT_ID
```

**Add a new secret version:**
```bash
echo -n "new-secret-value" | gcloud secrets versions add SECRET_NAME \
  --data-file=- \
  --project=PROJECT_ID
```

**Disable the old version** after confirming applications have migrated:
```bash
gcloud secrets versions disable VERSION_NUMBER \
  --secret=SECRET_NAME \
  --project=PROJECT_ID
```

**Destroy old version** (irreversible — do this only after a rotation cooldown period):
```bash
gcloud secrets versions destroy VERSION_NUMBER \
  --secret=SECRET_NAME \
  --project=PROJECT_ID
```

---

## Rotation After Suspected Compromise

If a key or secret is suspected compromised:

1. **Immediately create a new version** (KMS or Secret Manager)
2. **Disable/revoke the compromised version**
3. **Rotate all dependent secrets** (service account passwords, API keys using that KMS key)
4. **Check Cloud Audit Logs** for unauthorized use:
```bash
gcloud logging read \
  'protoPayload.serviceName="cloudkms.googleapis.com" AND protoPayload.methodName=~"Decrypt|Sign"' \
  --project=PROJECT_ID \
  --freshness=24h \
  --format=json | jq '.[] | {time: .timestamp, caller: .protoPayload.authenticationInfo.principalEmail, key: .protoPayload.resourceName}'
```
5. **File a security incident** following `docs/runbooks/incident-response.md`
6. **Notify the security team** via the SCC alert or Slack webhook

---

## Terraform State After Rotation

If Terraform manages the key and a new version is created out-of-band:
- Run `terraform plan` in the affected environment — the plan should show no drift (GCP auto-rotation does not change the resource ID)
- If the attestor key was manually updated, update `binary_authorization.tf` references and run `terraform apply`

---

## Related

- Rotate keys script: `scripts/rotate-keys.sh`
- KMS Terraform: `terraform/modules/security-baseline/kms.tf`
- Binary Auth Terraform: `terraform/modules/security-baseline/binary_authorization.tf`
- Incident response: `docs/runbooks/incident-response.md`
