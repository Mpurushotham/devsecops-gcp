# Network Design

## Overview

The network architecture enforces a zero-trust posture: all ingress and egress is denied by default, explicit allow rules are scoped to specific sources and ports, and all traffic within the VPC is logged. VPC Service Controls add a perimeter layer that prevents data exfiltration even if IAM controls are bypassed.

---

## VPC Layout

```
Organization
└── environments/
    ├── dev/
    │   └── VPC: dev-vpc (us-central1)
    ├── staging/
    │   └── VPC: staging-vpc (us-central1)
    └── prod/
        └── VPC: prod-vpc (us-central1)
```

Each environment has its own VPC. There is no VPC peering between environments — isolation is enforced at the project boundary.

### Subnet Design (per environment)

| Subnet | CIDR | Purpose | Secondary Ranges |
|---|---|---|---|
| `private-subnet-us-central1` | `10.{env}.0.0/20` | GKE nodes, Cloud Run | pods: `/16`, services: `/22` |

- `private_ip_google_access = true` — allows nodes to reach Google APIs without external IPs
- VPC Flow Logs enabled on all subnets: `INTERVAL_5_SEC`, `sampling_rate = 1.0`, `INCLUDE_ALL_METADATA`

---

## Firewall Rules

Rules follow a deny-all baseline with explicit allows. Priority 65534 deny rules block everything not explicitly permitted.

| Priority | Direction | Name | Source/Dest | Ports | Purpose |
|---|---|---|---|---|---|
| 65534 | INGRESS | `deny-all-ingress` | `0.0.0.0/0` | all | Default deny |
| 65534 | EGRESS | `deny-all-egress` | `0.0.0.0/0` | all | Default deny |
| 1000 | INGRESS | `allow-internal` | RFC1918 | all | Intra-VPC traffic |
| 1000 | INGRESS | `allow-health-checks` | GCP LB ranges | 80, 443, 8080, 8443 | GKE Ingress health probes |
| 1000 | INGRESS | `allow-iap-ssh` | `35.235.240.0/20` | 22 | Identity-Aware Proxy SSH |
| 1000 | EGRESS | `allow-google-apis` | `199.36.153.8/30` + `199.36.153.4/30` | 443 | Private Google APIs (VIP) |
| 1000 | EGRESS | `allow-dns` | `0.0.0.0/0` | 53 UDP/TCP | DNS resolution |

**No rule allows direct internet ingress.** External access is via GCP Load Balancer only (managed by GKE Ingress / Gateway API).

---

## Cloud NAT

GKE nodes and Cloud Run services use Cloud NAT for egress internet access. NAT is the only path for outbound internet traffic from private subnets.

```
Private Node → Cloud NAT → Static outbound IPs (logged) → Internet
```

The static NAT IPs should be allowlisted in any external services receiving traffic from this platform. All NAT translations are logged via VPC Flow Logs.

---

## GKE Network Architecture

### Dev / Staging

```
Internet → GCP Global LB → GKE Ingress (nginx / Gateway API)
                         ↓
              Kubernetes Services (ClusterIP)
                         ↓
                     GKE Pods
                    (private subnet)
```

- `enable_private_nodes = true` — nodes have no external IPs
- `enable_private_endpoint = false` — control plane accessible from authorized CIDRs (`0.0.0.0/0` in dev, restricted in staging)
- `master_authorized_networks`: `0.0.0.0/0` (dev), specific office/runner CIDRs (staging)

### Production

```
Internet → GCP Global LB → GKE Ingress
                         ↓
              Kubernetes Services (ClusterIP)
                         ↓
                     GKE Pods
                    (private subnet)

GitHub Actions → Cloud Build (inside VPC) → GKE control plane (private endpoint)
```

- `enable_private_endpoint = true` — control plane is only accessible from within the VPC
- `master_authorized_networks`: bastion CIDR only
- GitHub Actions cannot reach the control plane directly — must use Cloud Build as a proxy runner inside the VPC

---

## Kubernetes Network Policies

Network policies enforce pod-level microsegmentation on top of VPC firewall rules.

| Policy | Effect |
|---|---|
| `default-deny-all` | Denies all ingress and egress for all pods (applied first) |
| `allow-dns` | Allows egress to `kube-dns` pods on port 53 |
| `allow-monitoring` | Allows Prometheus scrape ingress (9090/8080/8443) + egress 443 for Google APIs |

Application teams must create explicit NetworkPolicy resources to allow traffic to/from their pods.

---

## VPC Service Controls

VPC-SC creates a logical security perimeter around GCP services, preventing data exfiltration even if an actor has valid IAM credentials.

### Protected Services (perimeter)
- `storage.googleapis.com`
- `bigquery.googleapis.com`
- `secretmanager.googleapis.com`
- `cloudkms.googleapis.com`
- `artifactregistry.googleapis.com`

### Deployment Stages

| Environment | Mode | Rationale |
|---|---|---|
| dev | Disabled | Avoid friction during development |
| staging | `DRY_RUN` | Observe violations without blocking |
| prod | `ENFORCE` | Full data exfiltration protection |

**Critical:** Never switch prod directly to `ENFORCE` without observing `DRY_RUN` violations for at least one week. A misconfigured perimeter in `ENFORCE` mode will block all API access for services inside the perimeter.

### Access Levels

Access to protected services is granted to:
- Terraform SA (for IaC operations)
- GKE node SAs (for artifact pull, secret access)
- Developer identities in `vpc_sc_allowed_members` (explicit list in `terraform.tfvars`)

### Monitoring VPC-SC Violations

```bash
gcloud logging read \
  'protoPayload.serviceName="accesscontextmanager.googleapis.com"
   OR
   protoPayload.status.code=403
   AND protoPayload.status.message=~"VPC Service Controls"' \
  --project=PROJECT_ID \
  --freshness=7d \
  --format=json
```

---

## DNS

- All internal resolution uses GCP's internal DNS (`*.internal`)
- Cloud DNS is used for any custom domains
- Nodes use `169.254.169.254` for metadata server access (Falco monitors for unexpected callers)
- GKE pods use `kube-dns` (CoreDNS) — protected by NetworkPolicy `allow-dns`

---

## Network Monitoring

| Signal | Source | Destination |
|---|---|---|
| VPC Flow Logs | All subnets | Cloud Logging → BQ sink |
| Firewall rule hits | Compute firewall | Cloud Logging |
| NAT translations | Cloud NAT | Cloud Logging |
| VPC-SC violations | Access Context Manager | Cloud Logging → alert policy |
| GKE audit logs | Kubernetes API | Cloud Logging |
| Falco network events | Kernel syscalls | Pub/Sub → Cloud Functions |

Alert policy `firewall_modified` fires within 5 minutes of any firewall rule creation or modification.

---

## Related

- Firewall Terraform: `terraform/modules/networking/firewall.tf`
- Subnets Terraform: `terraform/modules/networking/subnets.tf`
- VPC-SC Terraform: `terraform/modules/networking/vpc_service_controls.tf`
- GKE cluster Terraform: `terraform/modules/gke/cluster.tf`
- Network policies: `kubernetes/network-policies/`
