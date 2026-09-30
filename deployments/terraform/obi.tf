# OBI (OpenTelemetry eBPF Instrumentation) Kubernetes Resources
#
# OBI instruments every quickpizza-family process (catalog/config/copy/public-api/
# recommendations/ws/grpc) from outside them, via eBPF, instead of relying on the app's own
# OTel SDK. Deployed as a DaemonSet - one shared OBI instance per node, discovering every
# matching process on that node - mirroring this repo's compose.*.microservices.yaml
# precedent and OBI's own recommended topology for "multiple processes on one host". See
# docs/otel.md and https://opentelemetry.io/docs/zero-code/obi/setup/kubernetes/.
#
# var.enable_obi drives both this DaemonSet's existence and
# QUICKPIZZA_OTEL_INSTRUMENTATION_MODE (main.tf's quickpizza_common_env) - one variable, so
# the two can't drift out of sync the way the compose files' separate --profile obi flag and
# env var can.

locals {
  obi_component_labels = {
    "environment"                 = var.deployment_environment
    "app.k8s.io/name"             = "obi-app"
    "app.kubernetes.io/component" = "instrumentation"
    "app.kubernetes.io/instance"  = "obi"
  }
}

resource "kubernetes_service_account_v1" "obi" {
  count = var.enable_obi ? 1 : 0
  metadata {
    name      = "obi"
    namespace = kubernetes_namespace_v1.quickpizza.id
  }
}

# OBI needs its own ClusterRole (unlike alloy's, which just binds the built-in "view" role):
# "view" doesn't cover cluster-scoped "nodes", which OBI also needs to list/watch, alongside
# pods/services/replicasets, to resolve Kubernetes metadata (k8s.pod.name,
# k8s.deployment.name, ...) via OTEL_EBPF_KUBE_METADATA_ENABLE below.
resource "kubernetes_cluster_role_v1" "obi" {
  count = var.enable_obi ? 1 : 0
  metadata {
    name = "obi"
  }
  rule {
    api_groups = ["apps"]
    resources  = ["replicasets"]
    verbs      = ["list", "watch"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods", "services", "nodes"]
    verbs      = ["list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "obi" {
  count = var.enable_obi ? 1 : 0
  metadata {
    name = "obi"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.obi[0].metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.obi[0].metadata[0].name
    namespace = kubernetes_namespace_v1.quickpizza.id
  }
}

# Own template (obi.yaml.tftpl), not shared with the Docker Compose deployments: this one
# also needs a discovery.instrument block to scope which processes OBI instruments (see its
# own comment for why), which only makes sense with Kubernetes namespaces.
resource "kubernetes_config_map_v1" "obi_config" {
  count = var.enable_obi ? 1 : 0
  metadata {
    name      = "obi-config"
    namespace = kubernetes_namespace_v1.quickpizza.id
  }
  data = {
    "obi.yaml" = templatefile("${path.module}/obi.yaml.tftpl", {
      quickpizza_namespace = var.quickpizza_kubernetes_namespace
    })
  }
}

resource "kubernetes_daemon_set_v1" "obi" {
  count      = var.enable_obi ? 1 : 0
  depends_on = [kubernetes_deployment_v1.alloy]

  metadata {
    name      = "obi"
    namespace = kubernetes_namespace_v1.quickpizza.id
    labels    = local.obi_component_labels
  }
  spec {
    selector {
      match_labels = local.obi_component_labels
    }
    template {
      metadata {
        labels = local.obi_component_labels
      }
      spec {
        host_pid             = true
        service_account_name = kubernetes_service_account_v1.obi[0].metadata[0].name
        container {
          name = "obi"
          # Digest-pinned like this repo's other privileged/host-scoped Terraform images
          # (alloy.tf, database.tf) and QuickPizza's own image (variables.tf) - this container
          # runs privileged with host_pid, so a moved tag would silently start executing with
          # host-level access.
          image             = "otel/ebpf-instrument:v0.13.0@sha256:5e89d7478b5feeb8ee73881c58bfe5bb0ccb6dcd4f8cd62e30457aa6e6426adb"
          image_pull_policy = "IfNotPresent"
          args              = ["-config", "/obi-config.yaml"]
          security_context {
            privileged = true
          }
          env {
            name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
            value = "http://alloy:4318"
          }
          env {
            name  = "OTEL_EXPORTER_OTLP_PROTOCOL"
            value = "http/protobuf"
          }
          env {
            # Lets OBI attach k8s.namespace.name/k8s.pod.name/k8s.deployment.name resource
            # attributes itself, using the RBAC above - the compose deployments have no
            # Kubernetes API to query, so they don't set this.
            name  = "OTEL_EBPF_KUBE_METADATA_ENABLE"
            value = "true"
          }
          volume_mount {
            name       = "obi-config"
            mount_path = "/obi-config.yaml"
            sub_path   = "obi.yaml"
          }
          volume_mount {
            # A real Linux node should have tracefs mounted, unlike the local Docker Desktop
            # VM (see obi.yaml's comment) - this is what pinned-eBPF-map features need.
            name       = "tracefs"
            mount_path = "/sys/kernel/tracing"
          }
        }
        volume {
          name = "obi-config"
          config_map {
            name = kubernetes_config_map_v1.obi_config[0].metadata[0].name
          }
        }
        volume {
          name = "tracefs"
          host_path {
            path = "/sys/kernel/tracing"
            type = "Directory"
          }
        }
        restart_policy = "Always"
      }
    }
  }
}
