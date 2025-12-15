resource "helm_release" "grafana-k8s-monitoring" {
  count = var.enable_k8s_monitoring ? 1 : 0
  name             = "grafana-k8s-monitoring"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "k8s-monitoring"
  version          = "^1"
  namespace        = "quickpizza-monitoring"
  create_namespace = true
  atomic           = true
  timeout          = 300

  lifecycle {
    # this causes a warning saying it's redundant, but it is intentional,
    # see https://github.com/hashicorp/terraform-provider-helm/issues/1315
    ignore_changes = [metadata]
  }

  values = [file("${path.module}/k8-monitoring.yaml")]

  set {
    name  = "cluster.name"
    value = var.cluster_name
  }

  set {
    name  = "externalServices.prometheus.host"
    value = var.externalservices_prometheus_host
  }

  set_sensitive {
    name  = "externalServices.prometheus.basicAuth.username"
    value = var.externalservices_prometheus_basicauth_username
  }

  set_sensitive {
    name  = "externalServices.prometheus.basicAuth.password"
    value = var.externalservices_prometheus_basicauth_password
  }

  set {
    name  = "externalServices.loki.host"
    value = var.externalservices_loki_host
  }

  set_sensitive {
    name  = "externalServices.loki.basicAuth.username"
    value = var.externalservices_loki_basicauth_username
  }

  set_sensitive {
    name  = "externalServices.loki.basicAuth.password"
    value = var.externalservices_loki_basicauth_password
  }

  set {
    name  = "opencost.opencost.exporter.defaultClusterId"
    value = var.cluster_name
  }

  set {
    name  = "opencost.opencost.prometheus.external.url"
    value = format("%s/api/prom", var.externalservices_prometheus_host)
  }
}