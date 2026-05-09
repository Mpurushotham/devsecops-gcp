# Default deny all ingress (CIS 3.6)
resource "google_compute_firewall" "deny_all_ingress" {
  name    = "${var.vpc_name}-deny-all-ingress"
  project = var.project_id
  network = google_compute_network.vpc.self_link

  direction = "INGRESS"
  priority  = 65534

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Default deny all egress
resource "google_compute_firewall" "deny_all_egress" {
  name    = "${var.vpc_name}-deny-all-egress"
  project = var.project_id
  network = google_compute_network.vpc.self_link

  direction = "EGRESS"
  priority  = 65534

  deny {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Allow internal RFC1918 communication
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.vpc_name}-allow-internal"
  project = var.project_id
  network = google_compute_network.vpc.self_link

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
}

# Allow GCP health check probes (required for load balancers and GKE)
resource "google_compute_firewall" "allow_health_checks" {
  name    = "${var.vpc_name}-allow-health-checks"
  project = var.project_id
  network = google_compute_network.vpc.self_link

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
  }

  # GCP health check IP ranges
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]

  target_tags = ["gke-node", "allow-health-check"]
}

# Allow SSH via IAP only — no direct SSH from internet (CIS 3.6)
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "${var.vpc_name}-allow-iap-ssh"
  project = var.project_id
  network = google_compute_network.vpc.self_link

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # IAP tunnel IP range
  source_ranges = ["35.235.240.0/20"]
}

# Allow HTTPS egress to Google APIs (for Private Google Access)
resource "google_compute_firewall" "allow_google_apis_egress" {
  name    = "${var.vpc_name}-allow-google-apis"
  project = var.project_id
  network = google_compute_network.vpc.self_link

  direction = "EGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  # Google API ranges for Private Google Access
  destination_ranges = ["199.36.153.4/30", "199.36.153.8/30", "34.126.0.0/18"]
}

# Allow DNS egress
resource "google_compute_firewall" "allow_dns_egress" {
  name    = "${var.vpc_name}-allow-dns"
  project = var.project_id
  network = google_compute_network.vpc.self_link

  direction = "EGRESS"
  priority  = 1000

  allow {
    protocol = "udp"
    ports    = ["53"]
  }

  allow {
    protocol = "tcp"
    ports    = ["53"]
  }

  destination_ranges = ["0.0.0.0/0"]
}
