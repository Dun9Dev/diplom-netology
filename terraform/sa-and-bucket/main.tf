# Генерация случайного суффикса для уникальности имени бакета
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Сервисный аккаунт для Terraform
resource "yandex_iam_service_account" "terraform_sa" {
  name        = "terraform-sa"
  description = "Service account for Terraform operations"
}

# Назначение ролей сервисному аккаунту
resource "yandex_resourcemanager_folder_iam_member" "sa_editor" {
  folder_id = var.yc_folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.terraform_sa.id}"
}

# Создание статического ключа доступа для сервисного аккаунта
resource "yandex_iam_service_account_static_access_key" "sa_static_key" {
  service_account_id = yandex_iam_service_account.terraform_sa.id
  description        = "Static access key for Terraform"
}

# Создание бакета для хранения Terraform state
resource "yandex_storage_bucket" "tfstate_bucket" {
  bucket     = "${var.bucket_name}-${random_string.suffix.result}"
  folder_id  = var.yc_folder_id
  acl        = "private"
  
  # Включение версионирования для возможности отката
  versioning {
    enabled = true
  }
}

# Вывод информации о бакете и ключах
output "bucket_name" {
  description = "Name of the bucket for Terraform state"
  value       = yandex_storage_bucket.tfstate_bucket.bucket
}

output "service_account_id" {
  description = "ID of the service account"
  value       = yandex_iam_service_account.terraform_sa.id
}

output "access_key" {
  description = "Static access key"
  value       = yandex_iam_service_account_static_access_key.sa_static_key.access_key
  sensitive   = true
}

output "secret_key" {
  description = "Static secret key"
  value       = yandex_iam_service_account_static_access_key.sa_static_key.secret_key
  sensitive   = true
}
