# Вывод информации о кластере
output "k8s_cluster_id" {
  description = "ID of Kubernetes cluster"
  value       = yandex_kubernetes_cluster.diploma_k8s.id
}

output "k8s_cluster_external_endpoint" {
  description = "External endpoint of Kubernetes cluster"
  value       = yandex_kubernetes_cluster.diploma_k8s.master[0].external_v4_endpoint
}

output "node_group_id" {
  description = "ID of node group"
  value       = yandex_kubernetes_node_group.diploma_nodes.id
}

output "nat_instance_ip" {
  description = "Public IP of NAT instance"
  value       = yandex_compute_instance.nat.network_interface[0].nat_ip_address
}
