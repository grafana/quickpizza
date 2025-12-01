locals {
  database_component_labels = {
    "environment"                 = var.deployment_environment
    "app.k8s.io/name"            = "quickpizza-app"
    "app.kubernetes.io/component" = "database"
    "app.kubernetes.io/instance"  = "quickpizza-db"
  }
}

resource "kubernetes_config_map" "postgres_init_script" {
  metadata {
    name      = "postgres-init-script"
    namespace = kubernetes_namespace.quickpizza.metadata[0].name
  }
  data = {
    "init-db-observability.sh" = file("${path.module}/../scripts/init-db-observability.sh")
  }
}

resource "kubernetes_secret" "quickpizza_postgres_credentials" {
  metadata {
    name      = "quickpizza-db-credentials"
    namespace = kubernetes_namespace.quickpizza.metadata[0].name
  }
  data = {
    DATABASE_PASSWORD = var.quickpizza_db_password
    CONNECTION_STRING = format("postgres://%s:%s@%s/%s?sslmode=disable", var.quickpizza_db_user, var.quickpizza_db_password, kubernetes_service.postgres.metadata[0].name, var.quickpizza_db_name)
  }
}

resource "kubernetes_stateful_set" "postgres_statefulset" {
  metadata {
    name      = "quickpizza-db"
    namespace = kubernetes_namespace.quickpizza.metadata[0].name
    labels    = local.database_component_labels
  }
  spec {
    replicas = 1
    selector {
      match_labels = local.database_component_labels
    }
    service_name = kubernetes_service.postgres.metadata[0].name
    volume_claim_template {
      metadata {
        name = "data"
      }
      spec {
        access_modes = ["ReadWriteOnce"]
        resources {
          requests = {
            "storage" = "5Gi"
          }
        }
      }
    }
    template {
      metadata {
        labels = local.database_component_labels
      }
      spec {
        container {
          image = "postgres:18"
          name  = "postgres"
          
          args = [
            "-c", "shared_preload_libraries=pg_stat_statements",
            "-c", "track_activity_query_size=4096",
            "-c", "pg_stat_statements.track=all"
          ]
          
          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              memory = "256Mi"
            }
          }

          port {
            container_port = 5432
            name           = "psql"
          }

          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.quickpizza_postgres_credentials.metadata[0].name
                key  = "DATABASE_PASSWORD"
              }
            }
          }
          env {
            name  = "POSTGRES_DB"
            value = var.quickpizza_db_name
          }
          env {
            name  = "POSTGRES_USER"
            value = var.quickpizza_db_user
          }
          env { // init db observability
            name  = "DB_O11Y_DATABASES"
            value = var.quickpizza_db_name
          }
          volume_mount {
            mount_path = "/var/lib/postgresql"
            name       = "data"
          }

          volume_mount {
            name = "init"
            mount_path = "/docker-entrypoint-initdb.d"
          }
        }

        volume {
          name = "init"
          config_map {
            name = "postgres-init-script"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "postgres" {
  metadata {
    name      = "quickpizza-db"
    namespace = kubernetes_namespace.quickpizza.metadata[0].name
  }
  spec {
    port {
      port        = 5432
      name        = "psql"
      target_port = 5432
    }
    selector = local.database_component_labels
    type     = "ClusterIP"
  }
}
