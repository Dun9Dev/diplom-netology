# Дипломная работа: DevOps-инфраструктура в Yandex.Cloud - Выполнил Shestovskikh Daniil

---

## Цели работы

1. Подготовить облачную инфраструктуру на базе Yandex.Cloud.
2. Запустить и сконфигурировать Kubernetes кластер.
3. Установить и настроить систему мониторинга.
4. Настроить CI/CD для автоматической сборки и развёртывания тестового приложения.

---

## Этапы выполнения

### 1. Создание облачной инфраструктуры

> **Требования:**
> - Создать сервисный аккаунт с необходимыми правами.
> - Подготовить backend (S3 bucket) для хранения Terraform state.
> - Создать VPC с подсетями в разных зонах доступности.
> - Обеспечить возможность выполнять `terraform apply/destroy` без ручных действий.

#### Решение

Terraform-конфигурация разделена на две папки:
- `terraform/sa-and-bucket` — создание сервисного аккаунта, статического ключа и бакета для state.
- `terraform/infrastructure` — основная инфраструктура: VPC, подсети, NAT, кластер Managed Kubernetes, группа узлов.

```hcl
# Пример: создание VPC и подсетей (network.tf)
resource "yandex_vpc_network" "main" {
  name = "diploma-vpc"
}

resource "yandex_vpc_subnet" "public_a" {
  name           = "public-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}
# ... остальные подсети в зонах b и d
```

После применения Terraform получаем:

- VPC `diploma-vpc`
- 6 подсетей (public/private) в 3 зонах
- NAT instance
- Managed Kubernetes cluster (региональный мастер)
- Node group (прерываемые ВМ, автоскейлинг 2→4)

()[!https://github.com/Dun9Dev/diplom-netology/blob/main/img/Screenshot_20260513_215636.png]

---

### 2. Создание Kubernetes кластера

> **Требования:**
> - Использовать Managed Service for Kubernetes (региональный мастер).
> - Разместить ноды в 3 разных подсетях.
> - Обеспечить доступ к кластеру из интернета.
> - Команда `kubectl get pods --all-namespaces` должна работать без ошибок.

#### Решение

Кластер создан через Terraform-ресурсы:

```hcl
resource "yandex_kubernetes_cluster" "diploma_k8s" {
  name        = "diploma-k8s-cluster"
  network_id  = yandex_vpc_network.main.id

  master {
    version = "1.31"
    regional {
      region = "ru-central1"
      location { zone = "ru-central1-a"; subnet_id = yandex_vpc_subnet.public_a.id }
      location { zone = "ru-central1-b"; subnet_id = yandex_vpc_subnet.public_b.id }
      location { zone = "ru-central1-d"; subnet_id = yandex_vpc_subnet.public_d.id }
    }
    public_ip = true
  }

  service_account_id      = yandex_iam_service_account.k8s_sa.id
  node_service_account_id = yandex_iam_service_account.k8s_sa.id
}
```

Группа узлов:

```hcl
resource "yandex_kubernetes_node_group" "diploma_nodes" {
  cluster_id = yandex_kubernetes_cluster.diploma_k8s.id
  scale_policy {
    auto_scale { min = 2; max = 4; initial = 2 }
  }
  instance_template {
    resources { cores = 2; memory = 4; core_fraction = 20 }
    scheduling_policy { preemptible = true }
    network_interface { nat = true; subnet_ids = [yandex_vpc_subnet.public_a.id] }
  }
}
```

Результат:
*[https://github.com/Dun9Dev/diplom-netology/blob/main/img/Screenshot_20260513_230525.png]*

---

### 3. Создание тестового приложения

> **Требования:**
> - Отдельный git репозиторий с nginx и Dockerfile.
> - Публикация образа в Container Registry.

#### Решение

Создан репозиторий [diplom-app](https://github.com/Dun9Dev/diplom-app).

**Dockerfile:**
```dockerfile
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
```

**index.html** — статическая страница с информацией о версии приложения.

Образ собран и загружен в Yandex Container Registry:

```bash
docker build -t cr.yandex/crpvtth2thuc5g5660q5/diplom-app:v1.0.0 .
docker push cr.yandex/crpvtth2thuc5g5660q5/diplom-app:v1.0.0
```

*[https://github.com/Dun9Dev/diplom-netology/blob/main/img/Screenshot_20260513_230724.png]*

---

### 4. Мониторинг и деплой приложения

> **Требования:**
> - Развернуть Prometheus, Grafana, Alertmanager, Node Exporter.
> - Задеплоить тестовое приложение.
> - Обеспечить HTTP-доступ к Grafana и приложению.

#### Решение

**Установка мониторинга через Helm:**

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install monitoring prometheus-community/kube-prometheus-stack
```

**Доступ к Grafana:**

```bash
kubectl port-forward svc/monitoring-grafana 3000:80
```

Логин: `admin`, пароль получен командой:
```bash
kubectl get secret monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo
```

*[https://github.com/Dun9Dev/diplom-netology/blob/main/img/Screenshot_20260513_231121.png]*

*[https://github.com/Dun9Dev/diplom-netology/blob/main/img/Screenshot_20260513_221440.png]*

*[https://github.com/Dun9Dev/diplom-netology/blob/main/img/Screenshot_20260513_221502.png]*

**Деплой приложения в кластер:**

```bash
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

*[https://github.com/Dun9Dev/diplom-netology/blob/main/img/Screenshot_20260513_231417.png]*


Приложение доступно по адресу: **http://111.88.153.34**

---

### 5. CI/CD

> **Требования:**
> - Автоматическая сборка Docker-образа при коммите в репозиторий приложения.
> - Автоматический деплой в Kubernetes при создании тега (v1.0.0, v1.0.1, ...).

#### Решение

Использован **GitHub Actions**. Создан workflow `.github/workflows/docker-build.yml`:

```yaml
name: Build and Deploy to Yandex Cloud

on:
  push:
    branches: [ main ]
    tags: [ 'v*' ]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Login to Registry
        run: echo "${{ secrets.YC_TOKEN }}" | docker login --username oauth --password-stdin cr.yandex
      - name: Build and Push
        run: |
          docker build -t cr.yandex/${{ env.REGISTRY_ID }}/${{ env.IMAGE_NAME }}:${{ github.ref_name }} .
          docker push cr.yandex/${{ env.REGISTRY_ID }}/${{ env.IMAGE_NAME }}:${{ github.ref_name }}
      - name: Deploy on tag
        if: startsWith(github.ref, 'refs/tags/v')
        run: |
          kubectl set image deployment/diplom-app app=cr.yandex/${{ env.REGISTRY_ID }}/${{ env.IMAGE_NAME }}:${{ github.ref_name }}
```

**Секреты GitHub Actions:**

- `YC_TOKEN` — OAuth токен Yandex Cloud
- `KUBE_CONFIG` — статический kubeconfig для доступа к кластеру

*[https://github.com/Dun9Dev/diplom-netology/blob/main/img/Screenshot_20260513_224203.png]*

**Результат обновления приложения:**

*[https://github.com/Dun9Dev/diplom-netology/blob/main/img/Screenshot_20260513_224426.png]*

---

## Результат выполнения дипломного проекта

Все цели достигнуты:

- ✅ Облачная инфраструктура развёрнута.
- ✅ Kubernetes кластер работает.
- ✅ Приложение доступно по HTTP.
- ✅ Мониторинг (Grafana) показывает метрики кластера.
- ✅ CI/CD автоматизирует сборку и деплой.

---

## Ссылки на репозитории

| Репозиторий | Назначение |
|-------------|------------|
| [diplom-netology](https://github.com/Dun9Dev/diplom-netology) | Terraform (инфраструктура), манифесты K8S, README |
| [diplom-app](https://github.com/Dun9Dev/diplom-app) | Тестовое приложение (Dockerfile, index.html, CI/CD) |

---

## Доступ к сервисам

| Сервис | Адрес |
|--------|-------|
| Тестовое приложение | http://111.88.153.34 |
| Grafana | `kubectl port-forward svc/monitoring-grafana 3000:80` → http://localhost:3000 (логин: admin) |

