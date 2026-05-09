# Architecture Overview

## Platform Summary

This platform implements a production-grade DevSecOps lifecycle on GCP across three layers:

1. **Infrastructure** — Terraform-managed GCP resources, org policies, and networking
2. **Pipeline** — GitHub Actions workflows that gate every code and config change
3. **Runtime** — GKE with Gatekeeper, Falco, and Binary Authorization enforcing security at deploy and execution time

## GCP Organization Structure

```
Organization (org_id)
├── bootstrap/             ← seed project: Terraform state + WIF
├── common/                ← shared services (reserved)
├── environments/
│   ├── dev/               ← dev project
│   ├── staging/           ← staging project
│   └── prod/              ← prod project
├── security/              ← SCC response project, centralized logging
└── networking/            ← (reserved for shared VPC host projects)
```

## Authentication Flow

No service account keys are used anywhere. All GCP access from CI uses Workload Identity Federation:

```
GitHub Actions OIDC token
  └─► WIF Pool (github-actions-pool)
        └─► WIF Provider (github-provider)
              └─► Impersonate GCP Service Account
                    ├─► github-terraform-plan  (any branch)
                    ├─► github-terraform-apply (main branch only — separate WIF provider)
                    ├─► github-image-push      (any branch)
                    └─► github-prowler         (any branch)
```

## Security Control Layers

| Layer | Control | Tool |
|---|---|---|
| Code commit | Secret scanning | Gitleaks, TruffleHog |
| Pull request | IaC scanning | tfsec, checkov, terrascan |
| Pull request | SAST | CodeQL, Semgrep |
| Pull request | SCA | Trivy (fs), OWASP Dependency-Check |
| Main branch | Container scanning | Trivy (image), Grype |
| Main branch | SBOM generation | Syft + GitHub Attestations |
| Main branch | Image signing | Cosign (keyless) |
| Main branch | Binary Authorization | KMS-signed attestation |
| Cluster admission | Policy enforcement | OPA Gatekeeper (10 constraints) |
| Runtime | Threat detection | Falco (20+ custom rules) |
| Org-wide | Compliance scanning | Prowler (CIS GCP 2.0 + SOC 2) |
| Org-wide | Finding response | SCC → Pub/Sub → Cloud Function |
| Org-wide | Audit logging | Cloud Logging → BigQuery + GCS (7yr) |
