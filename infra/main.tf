terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0"
    }
  }
  required_version = ">= 1.3"
}

provider "google" {
  project = var.project_id
  region  = var.region
}
resource "google_service_account" "cloudbuild_service_account" {
  account_id   = "cloudbuild-sa"
  display_name = "Cloud Build Service Account"
}

resource "google_service_account" "cloud_run_sa" {
  account_id   = var.cloudrun_sa_name
  display_name = "Cloud Run Service Account"
}

resource "google_project_iam_member" "run_sa_secret_access" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:springboot-cloudrun-sa@${var.project_id}.iam.gserviceaccount.com"
}

resource "google_cloud_run_service_iam_member" "public_invoker" {
  location = var.region
  service  = google_cloud_run_service.springboot.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}



resource "google_project_iam_member" "run_sa_sql_access" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:springboot-cloudrun-sa@${var.project_id}.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "cloudbuild_service_account_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.cloudbuild_service_account.email}"
}

resource "google_project_service" "required_services" {
  for_each = toset([
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudbuild.googleapis.com",
    "iam.googleapis.com"
  ])
  project = var.project_id
  service = each.key

  # Prevent Terraform from disabling the API
  disable_on_destroy = false
}

resource "google_secret_manager_secret" "db_password" {
  secret_id = var.db_password_secret_id
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password_version" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = var.db_password
}



resource "google_secret_manager_secret_iam_member" "db_password_access" {
  secret_id = google_secret_manager_secret.db_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}





resource "google_sql_database_instance" "postgres_instance" {
  name             = "postgres-instance"
  database_version = "POSTGRES_15"
  region           = var.region

  settings {
    tier = "db-f1-micro"
  }

  # deletion_protection = false  # ✅ Required for deletion
}


resource "google_sql_user" "db_user" {
  name      = var.db_user
  instance  = google_sql_database_instance.postgres_instance.name
  password = var.db_password
}

resource "google_sql_database" "studentdb" {
  name     = var.db_name
  instance = google_sql_database_instance.postgres_instance.name
}

resource "google_cloud_run_service" "springboot" {
  name     = var.cloud_run_service_name
  location = var.region

  template {
    spec {
      service_account_name = google_service_account.cloud_run_sa.email

      containers {
        image = "gcr.io/${var.project_id}/${var.cloud_run_service_name}"

        env {
          name  = "SPRING_DATASOURCE_URL"
          value = "jdbc:postgresql:///${var.db_name}?cloudSqlInstance=${var.project_id}:${var.region}:${var.db_instance_name}&socketFactory=com.google.cloud.sql.postgres.SocketFactory&user=${var.db_user}"
        }

        env {
          name = "SPRING_DATASOURCE_PASSWORD"
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.db_password.secret_id
              key  = "latest"
            }
          }
        }

        ports {
          container_port = 8080
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  autogenerate_revision_name = true
}


resource "google_cloudbuild_trigger" "manual_trigger" {
  name        = "manual-springboot-deploy"
  description = "Manual trigger for building and deploying Spring Boot app"

  github {
    owner = "Ashish080"  # Add your GitHub owner/org
    name  = "springboot_gcp"     # This should match your actual repo name
    push {
      branch = "main"
    }
  }

  filename = "cloudbuild.yaml"
  
  substitutions = {
    _SERVICE_NAME = var.cloud_run_service_name
    _REGION       = var.region
    _DB_INSTANCE  = "${var.project_id}:${var.region}:postgres-instance"
    _DB_NAME      = var.db_name
    _DB_USER      = var.db_user
  }

  # Add dependency on the services being enabled
  depends_on = [
    google_project_service.required_services
  ]
}

