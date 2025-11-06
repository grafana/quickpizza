resource "kubernetes_service" "quickpizza" {
  metadata {
    annotations = {
      "k8s.grafana.com/scrape"             = true
      "k8s.grafana.com/job"                = "quickpizza/quickpizza-monolith"
      "k8s.grafana.com/metrics.portNumber" = 3333
    }
    name      = "quickpizza-monolith"
    namespace = kubernetes_namespace.quickpizza.id
  }
  spec {
    port {
      protocol    = "TCP"
      port        = 3333
      target_port = "3333"
    }
    selector = {
      "app.k8s.io/name"            = "quickpizza"
      "app.kubernetes.io/instance" = "quickpizza-monolith"
    }
    type = "LoadBalancer"
  }

  wait_for_load_balancer = false
}