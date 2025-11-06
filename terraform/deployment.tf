
resource "kubernetes_secret" "quickpizza_credentials" {
  metadata {
    name      = "quickpizza-credentials"
    namespace = kubernetes_namespace.quickpizza.id
  }
  data = {
    QUICKPIZZA_CONF_FARO_URL = var.quickpizza_conf_faro_url
    QUICKPIZZA_CONF_FARO_APP_NAME = var.quickpizza_conf_faro_app_name
  }
}

resource "kubernetes_deployment" "quickpizza" {
  depends_on = [kubernetes_deployment.grafana_alloy]
  
  metadata {
    name      = "quickpizza-monolith"
    namespace = kubernetes_namespace.quickpizza.id
    labels = {
      "app.k8s.io/name"             = "quickpizza"
      "app.kubernetes.io/component" = "service"
      "app.kubernetes.io/instance"  = "quickpizza-monolith"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        "app.k8s.io/name"            = "quickpizza"
        "app.kubernetes.io/instance" = "quickpizza-monolith"
      }
    }
    template {
      metadata {
        name = "quickpizza-monolith"
        labels = {
          "app.k8s.io/name"            = "quickpizza"
          "app.kubernetes.io/instance" = "quickpizza-monolith"
        }
      }
      spec {
        container {
          name              = "quickpizza-monolith"
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
              name = kubernetes_secret.quickpizza_credentials.metadata[0].name
            }
          }
          env {
            name  = "QUICKPIZZA_OTLP_ENDPOINT"
            value = "http://grafana-alloy:4318"
          }
          env {
            name  = "QUICKPIZZA_TRUST_CLIENT_TRACEID"
            value = true
          }
          env {
            name  = "QUICKPIZZA_ENABLE_ALL_SERVICES"
            value = "1"
          }
          env {
            name  = "QUICKPIZZA_OTEL_SERVICE_INSTANCE_ID"
            value = "quickpizza"
          }
          env {
            name  = "QUICKPIZZA_OTEL_SERVICE_NAME"
            value = "quickpizza"
          }
          env {
            name  = "QUICKPIZZA_LOG_LEVEL"
            value = var.quickpizza_log_level
          }
          env {
            name  = "OTEL_LOG_LEVEL"
            value = "debug"
          }
          resources {
            requests = {
              cpu    = "5m"
              memory = "64Mi"
            }
          }
        }
        restart_policy = "Always"
      }
    }
  }
}