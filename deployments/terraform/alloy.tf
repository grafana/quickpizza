# Grafana Alloy Kubernetes Resources

locals {
  alloy_component_labels = {
    "environment"                = var.deployment_environment
    "app.k8s.io/name"            = "alloy-app"
    "app.kubernetes.io/component" = "service"
    "app.kubernetes.io/instance"  = "alloy"
  }
}

resource "kubernetes_service_account_v1" "alloy" {
  metadata {
    name      = "alloy"
    namespace = kubernetes_namespace_v1.quickpizza.id
  }
}

// Grant the "view" ClusterRole to kubernetes_service_account_v1
// This allows Alloy (`service_account_name`) to discover application pods and scrape metrics. 
resource "kubernetes_role_binding_v1" "alloy" {
  metadata {
    name      = "alloy"
    namespace = kubernetes_namespace_v1.quickpizza.id
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "view"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.alloy.metadata[0].name
    namespace = kubernetes_namespace_v1.quickpizza.id
  }
}

resource "kubernetes_config_map_v1" "alloy_config" {
  metadata {
    name      = "alloy-config"
    namespace = kubernetes_namespace_v1.quickpizza.id
  }
  data = {
    "config.alloy" = file("${path.module}/alloy/config.alloy")
  }
}

resource "kubernetes_secret_v1" "alloy_credentials" {
  metadata {
    name      = "alloy-credentials"
    namespace = kubernetes_namespace_v1.quickpizza.id
  }
  data = {
    GRAFANA_CLOUD_STACK = var.grafana_cloud_stack
    GRAFANA_CLOUD_TOKEN = var.grafana_cloud_token
  }
  type = "Opaque"
}

resource "kubernetes_deployment_v1" "alloy" {
  depends_on = [
    kubernetes_stateful_set_v1.postgres_statefulset
  ]
  metadata {
    name      = "alloy"
    namespace = kubernetes_namespace_v1.quickpizza.id
    labels = local.alloy_component_labels
  }
  spec {
    replicas = 1
    selector {
      match_labels = local.alloy_component_labels
    }
    template {
      metadata {
        labels = merge(
          local.alloy_component_labels,
          {
            # Add database-related labels for Database Observability
            "db.service.namespace" = kubernetes_namespace_v1.quickpizza.metadata[0].name
            "db.service.name"      = "quickpizza-db"
          }
        )
      }
      spec {
        service_account_name = kubernetes_service_account_v1.alloy.metadata[0].name
        container {
          name              = "alloy"
          image             = "grafana/alloy:v1.12.0"
          image_pull_policy = "IfNotPresent"
          args = [
            "run",
            "/conf/config.alloy",
            "--stability.level=public-preview"
          ]
          env_from {
            secret_ref {
              name = kubernetes_secret_v1.alloy_credentials.metadata[0].name
            }
          }
          env {
            name = "DB_O11Y_CONNECTION"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.quickpizza_postgres_credentials.metadata[0].name
                key  = "DB_O11Y_CONNECTION_STRING"
              }
            }
          }
          env {
            name  = "CLUSTER_NAME"
            value = var.cluster_name
          }
          env {
            name  = "QUICKPIZZA_PYROSCOPE_SERVICE_GIT_REF"
            value = var.quickpizza_git_ref
          }
          # Use Downward API to inject pod labels as environment variables
          env {
            name = "DB_SERVICE_NAMESPACE"
            value_from {
              field_ref {
                field_path = "metadata.labels['db.service.namespace']"
              }
            }
          }
          env {
            name = "DB_SERVICE_NAME"
            value_from {
              field_ref {
                field_path = "metadata.labels['db.service.name']"
              }
            }
          }
          env {
            name = "DEPLOYMENT_ENVIRONMENT"
            value_from {
              field_ref {
                field_path = "metadata.labels['environment']"
              }
            }
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

resource "kubernetes_service_v1" "alloy" {
  metadata {
    name      = "alloy"
    namespace = kubernetes_namespace_v1.quickpizza.id
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
