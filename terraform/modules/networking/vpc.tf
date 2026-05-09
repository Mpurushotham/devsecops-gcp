resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  project                 = var.project_id
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"

  # Delete default routes; explicit routes are created via subnets/NAT
  delete_default_routes_on_create = false
}
