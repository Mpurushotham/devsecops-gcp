output "dev_project_id" {
  value = module.dev_project.project_id
}

output "gke_cluster_name" {
  value = module.gke.cluster_name
}

output "registry_url" {
  value = module.artifact_registry.registry_url
}

output "scc_pubsub_topic" {
  value = module.scc_response.scc_pubsub_topic
}
