variable "yc_token" {
  description = "Yandex Cloud OAuth token"
  type        = string
  sensitive   = true
}

variable "yc_cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
}

variable "yc_folder_id" {
  description = "Yandex Cloud Folder ID"
  type        = string
}

variable "zone_a" {
  description = "Availability zone A"
  type        = string
  default     = "ru-central1-a"
}

variable "zone_b" {
  description = "Availability zone B"
  type        = string
  default     = "ru-central1-b"
}

variable "zone_d" {
  description = "Availability zone D"
  type        = string
  default     = "ru-central1-d"
}

# Параметры Kubernetes кластера
variable "k8s_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "node_group_size" {
  description = "Initial size of node group"
  type        = number
  default     = 2
}

variable "node_group_min" {
  description = "Minimum size of node group"
  type        = number
  default     = 2
}

variable "node_group_max" {
  description = "Maximum size of node group"
  type        = number
  default     = 4
}
