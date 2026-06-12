resource "kubernetes_namespace_v1" "quickpizza" {
  metadata {
    name = var.quickpizza_kubernetes_namespace
  }

  lifecycle {
    precondition {
      condition     = !var.quickpizza_enforce_image_digest || strcontains(var.quickpizza_image, ":${var.quickpizza_image_version}@sha256:")
      error_message = "quickpizza_image_version (${var.quickpizza_image_version}) must match the tag in quickpizza_image (${var.quickpizza_image}). Set quickpizza_enforce_image_digest=false to skip for local development."
    }
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
      value = "deployment.environment=${var.deployment_environment},service.version=${var.quickpizza_image_version}"
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