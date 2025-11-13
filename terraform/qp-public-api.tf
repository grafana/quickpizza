locals {
  public_api_component_labels = {
    "environment"                = var.deployment_environment
    "app.k8s.io/name"            = "quickpizza-app"
    "app.kubernetes.io/component" = "service"
    "app.kubernetes.io/instance"  = "public-api"
  }
}

resource "kubernetes_secret" "public_api" {
  metadata {
    name      = "public-api"
    namespace = kubernetes_namespace.quickpizza.id
  }
  data = {
    QUICKPIZZA_CONF_FARO_URL = var.quickpizza_conf_faro_url
    QUICKPIZZA_CONF_FARO_APP_NAME = var.quickpizza_conf_faro_app_name
  }
}

resource "kubernetes_deployment" "public_api" {
  depends_on = [kubernetes_deployment.alloy]
  
  metadata {
    name      = "public-api"
    namespace = kubernetes_namespace.quickpizza.id
    labels    = local.public_api_component_labels
  }
  spec {
    replicas = 1
    selector {
      match_labels = local.public_api_component_labels
    }
    template {
      metadata {
        labels = local.public_api_component_labels
      }
      spec {
        container {
          name              = "public-api"
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
          env_from {
            secret_ref {
              name = kubernetes_secret.public_api.metadata[0].name
            }
          }
          dynamic "env" {
            for_each = local.quickpizza_common_env
            content {
              name  = env.value.name
              value = env.value.value
            }
          }
          env {
            name  = "QUICKPIZZA_ENABLE_PUBLIC_API_SERVICE"
            value = "1"
          }
          env {
            name  = "QUICKPIZZA_OTEL_SERVICE_NAME"
            value = "public-api"
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

resource "kubernetes_service" "public_api" {
  metadata {
    name      = "public-api"
    namespace = kubernetes_namespace.quickpizza.id
  }
  spec {
    port {
      protocol    = "TCP"
      port        = 3333
      target_port = "3333"
    }
    selector = local.public_api_component_labels
    type = "LoadBalancer"
  }

  wait_for_load_balancer = false
}