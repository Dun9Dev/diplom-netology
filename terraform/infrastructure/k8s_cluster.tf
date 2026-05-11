# Сервисный аккаунт для Kubernetes кластера
resource "yandex_iam_service_account" "k8s_sa" {
  name        = "k8s-service-account"
  description = "Service account for Kubernetes cluster"
}

# Назначение ролей сервисному аккаунту
resource "yandex_resourcemanager_folder_iam_member" "k8s_sa_editor" {
  folder_id = var.yc_folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_sa_kms" {
  folder_id = var.yc_folder_id
  role      = "kms.keys.encrypterDecrypter"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_sa.id}"
}

# Региональный мастер Kubernetes
resource "yandex_kubernetes_cluster" "diploma_k8s" {
  name        = "diploma-k8s-cluster"
  description = "Kubernetes cluster for diploma"
  network_id  = yandex_vpc_network.main.id

  master {
    version = var.k8s_version
    regional {
      region = "ru-central1"

      location {
        zone      = var.zone_a
        subnet_id = yandex_vpc_subnet.public_a.id
      }
      location {
        zone      = var.zone_b
        subnet_id = yandex_vpc_subnet.public_b.id
      }
      location {
        zone      = var.zone_d
        subnet_id = yandex_vpc_subnet.public_d.id
      }
    }
    public_ip = true
  }

  service_account_id      = yandex_iam_service_account.k8s_sa.id
  node_service_account_id = yandex_iam_service_account.k8s_sa.id

  depends_on = [
    yandex_resourcemanager_folder_iam_member.k8s_sa_editor,
    yandex_resourcemanager_folder_iam_member.k8s_sa_kms
  ]
}
