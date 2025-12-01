
locals {
  copy_component_labels = {
    "environment"                = var.deployment_environment
    "app.k8s.io/name"            = "quickpizza-app"
    "app.kubernetes.io/component" = "service"
    "app.kubernetes.io/instance"  = "copy"
  }
}

resource "kubernetes_deployment" "copy" {
  depends_on = [
    kubernetes_deployment.alloy,
    kubernetes_stateful_set.postgres_statefulset
  ]
  
  metadata {
    name      = "copy"
    namespace = kubernetes_namespace.quickpizza.id
    labels    = local.copy_component_labels
  }
  spec {
    replicas = 1
    selector {
      match_labels = local.copy_component_labels
    }
    template {
      metadata {
        labels = local.copy_component_labels
      }
      spec {
        container {
          name              = "copy"
          image             = var.quickpizza_image
          image_pull_policy = var.quickpizza_image_pull_policy
          liveness_probe {
            http_get {
              path = "/healthz"
              port = 3333
            }
            initial_delay_seconds = 10
            timeout_seconds       = 3
            period_seconds        = 10
            failure_threshold     = 3
          }
          readiness_probe {
            http_get {
              path = "/ready"
              port = 3333
            }
            initial_delay_seconds = 5
            timeout_seconds       = 3
            period_seconds        = 5
            failure_threshold     = 3
          }
          port {
            name           = "http"
            container_port = 3333
          }
          dynamic "env" {
            for_each = local.quickpizza_common_env
            content {
              name  = env.value.name
              value = env.value.value
            }
          }
          env {
            name  = "QUICKPIZZA_ENABLE_COPY_SERVICE"
            value = "1"
          }
          env {
            name  = "QUICKPIZZA_OTEL_SERVICE_NAME"
            value = "copy"
          }
          env {
            name = "QUICKPIZZA_OTEL_SERVICE_INSTANCE_ID"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }
          env {
            name  = "QUICKPIZZA_OTEL_DB_NAME"
            value = "quickpizza-db"
          }
          env {
            name = "QUICKPIZZA_DB"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.quickpizza_postgres_credentials.metadata[0].name
                key  = "CONNECTION_STRING"
              }
            }
          }
          resources {
            requests = local.default_resources.requests
          }
        }
        restart_policy = "Always"
      }
    }
  }
}

resource "kubernetes_service" "copy" {
  metadata {
    name      = "copy"
    namespace = kubernetes_namespace.quickpizza.id
  }
  spec {
    port {
      protocol    = "TCP"
      port        = 3333
      target_port = "3333"
    }
    selector = local.copy_component_labels
    type = "ClusterIP"
  }
}