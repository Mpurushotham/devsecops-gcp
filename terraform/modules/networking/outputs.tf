output "vpc_self_link" {
  value = google_compute_network.vpc.self_link
}

output "vpc_name" {
  value = google_compute_network.vpc.name
}

output "subnet_self_link" {
  value = google_compute_subnetwork.main.self_link
}

output "subnet_name" {
  value = google_compute_subnetwork.main.name
}

output "pod_range_name" {
  value = "gke-pods"
}

output "service_range_name" {
  value = "gke-services"
}
