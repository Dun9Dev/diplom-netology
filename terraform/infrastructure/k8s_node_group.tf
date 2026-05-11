# Группа узлов Kubernetes (прерываемые ВМ для экономии)
resource "yandex_kubernetes_node_group" "diploma_nodes" {
  name        = "diploma-node-group"
  description = "Node group for diploma Kubernetes cluster"
  cluster_id  = yandex_kubernetes_cluster.diploma_k8s.id
  version     = var.k8s_version

  # Размещение в одной зоне (для экономии бюджета)
  allocation_policy {
    location {
      zone      = var.zone_a
      subnet_id = yandex_vpc_subnet.public_a.id
    }
  }

  # Автомасштабирование
  scale_policy {
    auto_scale {
      min     = var.node_group_min
      max     = var.node_group_max
      initial = var.node_group_size
    }
  }

  # Платформа и ресурсы нод (прерываемые для экономии)
  instance_template {
    platform_id = "standard-v3"
    resources {
      cores         = 2
      memory        = 4
      core_fraction = 20  # 20% CPU для экономии бюджета
    }

    boot_disk {
      type = "network-hdd"
      size = 64
    }

    network_interface {
      nat        = true
      subnet_ids = [yandex_vpc_subnet.public_a.id]
    }

    # Прерываемые ВМ
    scheduling_policy {
      preemptible = true
    }
  }

  depends_on = [
    yandex_kubernetes_cluster.diploma_k8s
  ]
}
