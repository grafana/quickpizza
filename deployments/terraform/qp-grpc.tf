locals {
  grpc_component_labels = {
    "environment"                  = var.deployment_environment
    "app.k8s.io/name"              = "quickpizza-app"
    "app.kubernetes.io/component"  = "service"
    "app.kubernetes.io/instance"   = "grpc"
  }
}

resource "kubernetes_deployment_v1" "grpc" {
  depends_on = [kubernetes_deployment_v1.alloy]

  metadata {
    name      = "grpc"
    namespace = kubernetes_namespace_v1.quickpizza.id
    labels    = local.grpc_component_labels
  }
  spec {
    replicas = 1
    selector {
      match_labels = local.grpc_component_labels
    }
    template {
      metadata {
        labels = local.grpc_component_labels
      }
      spec {
        container {
          name              = "grpc"
          image             = var.quickpizza_image
          image_pull_policy = var.quickpizza_image_pull_policy
          liveness_probe {
            http_get {
              path = "/grpchealthz"
              port = 3335
            }
            initial_delay_seconds = 10
            timeout_seconds       = 3
            period_seconds        = 10
            failure_threshold     = 3
          }
          readiness_probe {
            http_get {
              path = "/grpchealthz"
              port = 3335
            }
            initial_delay_seconds = 5
            timeout_seconds       = 3
            period_seconds        = 5
            failure_threshold     = 3
          }
          port {
            name           = "grpc"
            container_port = 3334
          }
          port {
            name           = "grpc-health"
            container_port = 3335
          }
          dynamic "env" {
            for_each = local.quickpizza_common_env
            content {
              name  = env.value.name
              value = env.value.value
            }
          }
          env {
            name  = "QUICKPIZZA_ENABLE_GRPC_SERVICE"
            value = "1"
          }
          env {
            name  = "QUICKPIZZA_OTEL_SERVICE_NAME"
            value = "grpc"
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

resource "kubernetes_service_v1" "grpc" {
  metadata {
    name      = "grpc"
    namespace = kubernetes_namespace_v1.quickpizza.id
  }
  spec {
    port {
      protocol    = "TCP"
      port        = 3334
      target_port = "3334"
    }
    selector = local.grpc_component_labels
    type     = "LoadBalancer"
  }

  wait_for_load_balancer = false
}
