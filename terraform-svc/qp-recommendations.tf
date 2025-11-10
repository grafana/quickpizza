
locals {
  recommendations_component_labels = {
    "environment"                = var.deployment_environment
    "app.k8s.io/name"            = "quickpizza-app"
    "app.kubernetes.io/component" = "service"
    "app.kubernetes.io/instance"  = "recommendations"
  }
}


resource "kubernetes_deployment" "recommendations" {
  depends_on = [kubernetes_deployment.alloy]
  
  metadata {
    name      = "recommendations"
    namespace = kubernetes_namespace.quickpizza.id
    labels    = local.recommendations_component_labels
  }
  spec {
    replicas = 1
    selector {
      match_labels = local.recommendations_component_labels
    }
    template {
      metadata {
        labels = local.recommendations_component_labels
      }
      spec {
        container {
          name              = "recommendations"
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
            name  = "QUICKPIZZA_ENABLE_RECOMMENDATIONS_SERVICE"
            value = "1"
          }
          env {
            name  = "QUICKPIZZA_OTEL_SERVICE_NAME"
            value = "recommendations"
          }
          env {
            name = "QUICKPIZZA_OTEL_SERVICE_INSTANCE_ID"
            value_from {
              field_ref {
                field_path = "metadata.name"
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

resource "kubernetes_service" "recommendations" {
  metadata {
    name      = "recommendations"
    namespace = kubernetes_namespace.quickpizza.id
  }
  spec {
    port {
      protocol    = "TCP"
      port        = 3333
      target_port = "3333"
    }
    selector = local.recommendations_component_labels
    type = "ClusterIP"
  }
}