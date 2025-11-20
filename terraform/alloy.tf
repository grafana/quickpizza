# Grafana Alloy Kubernetes Resources

locals {
  alloy_component_labels = {
    "environment"                = var.deployment_environment
    "app.k8s.io/name"            = "alloy-app"
    "app.kubernetes.io/component" = "service"
    "app.kubernetes.io/instance"  = "alloy"
  }
}

resource "kubernetes_service_account" "alloy" {
  metadata {
    name      = "alloy"
    namespace = kubernetes_namespace.quickpizza.id
  }
}

// Grant the "view" ClusterRole to kubernetes_service_account
// This allows Alloy (`service_account_name`) to discover application pods and scrape metrics. 
resource "kubernetes_role_binding" "alloy" {
  metadata {
    name      = "alloy"
    namespace = kubernetes_namespace.quickpizza.id
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "view"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.alloy.metadata[0].name
    namespace = kubernetes_namespace.quickpizza.id
  }
}

resource "kubernetes_config_map" "alloy_config" {
  metadata {
    name      = "alloy-config"
    namespace = kubernetes_namespace.quickpizza.id
  }
  data = {
    "config.alloy" = file("${path.module}/alloy/config.alloy")
  }
}

resource "kubernetes_secret" "alloy_credentials" {
  metadata {
    name      = "alloy-credentials"
    namespace = kubernetes_namespace.quickpizza.id
  }
  data = {
    GRAFANA_CLOUD_STACK = var.grafana_cloud_stack
    GRAFANA_CLOUD_TOKEN = var.grafana_cloud_token
  }
  type = "Opaque"
}

resource "kubernetes_deployment" "alloy" {
  metadata {
    name      = "alloy"
    namespace = kubernetes_namespace.quickpizza.id
    labels = local.alloy_component_labels
  }
  spec {
    replicas = 1
    selector {
      match_labels = local.alloy_component_labels
    }
    template {
      metadata {
        labels = local.alloy_component_labels
      }
      spec {
        service_account_name = kubernetes_service_account.alloy.metadata[0].name
        container {
          name              = "alloy"
          image             = "grafana/alloy:v1.11.3"
          image_pull_policy = "IfNotPresent"
          args = [
            "run",
            "/conf/config.alloy",
            "--stability.level=experimental"
          ]
          env_from {
            secret_ref {
              name = kubernetes_secret.alloy_credentials.metadata[0].name
            }
          }
          env {
            name  = "KUBERNETES_CLUSTER_NAME"
            value = var.cluster_name
          }
          env {
            name  = "QUICKPIZZA_PYROSCOPE_SERVICE_GIT_REF"
            value = var.quickpizza_git_ref
          }
          port {
            name           = "grpc"
            container_port = 4317
          }
          port {
            name           = "http"
            container_port = 4318
          }
          resources {
            requests = {
              cpu    = "5m"
              memory = "64Mi"
            }
          }
          volume_mount {
            mount_path = "/conf"
            name       = "alloy-config"
          }
        }
        restart_policy = "Always"
        volume {
          name = "alloy-config"
          config_map {
            name = "alloy-config"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "alloy" {
  metadata {
    name      = "alloy"
    namespace = kubernetes_namespace.quickpizza.id
  }
  spec {
    port {
      port        = 12345
      name        = "http-metrics"
      target_port = 12345
    }
    port {
      port        = 4317
      name        = "grpc"
      target_port = "grpc"
    }
    port {
      port        = 4318
      name        = "http"
      target_port = "http"
    }
    selector = local.alloy_component_labels
    type = "ClusterIP"
  }
}
