resource "kubernetes_namespace" "quickpizza" {
  metadata {
    name = var.kubernetes_namespace
  }
}

locals {
  quickpizza_common_env = [
    {
      name  = "QUICKPIZZA_CATALOG_ENDPOINT"
      value = "http://catalog:3333"
    },
    {
      name  = "QUICKPIZZA_COPY_ENDPOINT"
      value = "http://copy:3333"
    },
    {
      name  = "QUICKPIZZA_WS_ENDPOINT"
      value = "http://ws:3333"
    },
    {
      name  = "QUICKPIZZA_RECOMMENDATIONS_ENDPOINT"
      value = "http://recommendations:3333"
    },
    {
      name  = "QUICKPIZZA_CONFIG_ENDPOINT"
      value = "http://config:3333"
    },
    {
      name  = "QUICKPIZZA_ENABLE_ALL_SERVICES"
      value = 0
    },
    {
      name  = "QUICKPIZZA_OTLP_ENDPOINT"
      value = "http://alloy:4318"
    },
    {
      name  = "QUICKPIZZA_TRUST_CLIENT_TRACEID"
      value = true
    },
    {
      name  = "OTEL_RESOURCE_ATTRIBUTES"
      value = "deployment.environment=${var.deployment_environment},service.version=${var.quickpizza_image}"
    },
    {
      name  = "QUICKPIZZA_LOG_LEVEL"
      value = var.quickpizza_log_level
    }
  ]
  default_resources = {
    requests = {
      cpu    = "5m"
      memory = "64Mi"
    }
  }
}