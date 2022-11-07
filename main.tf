terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.42.0"
    }
  }
  backend "gcs" {
    bucket = "bucket-tfstate-9755a02f7829dc9a"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = "tokyo-house-366821"
  region  = "us-west1"
  zone    = "us-west1-b"
}

resource "google_storage_bucket" "tf-state" {
  name          = "bucket-tfstate-9755a02f7829dc9a"
  force_destroy = false
  location      = "us-west1"
  storage_class = "STANDARD"
  versioning {
    enabled = true
  }
}

resource "google_storage_bucket" "osm" {
  name          = "bucket-osm-9755a02f7829dc9a"
  force_destroy = false
  location      = "us-west1"
  storage_class = "STANDARD"
}

resource "google_storage_bucket" "osm-cities" {
  name          = "bucket-osm-cities-9755a02f7829dc9a"
  force_destroy = false
  location      = "us-west1"
  storage_class = "STANDARD"
}

variable "gcp_service_list" {
  description = "The list of apis necessary for the project"
  type        = list(string)
  default = [
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "logging.googleapis.com",
    "pubsub.googleapis.com",
    "storage.googleapis.com",
    "storage-component.googleapis.com",
    "storage-api.googleapis.com",
    "cloudfunctions.googleapis.com",
    "eventarc.googleapis.com",
    "compute.googleapis.com",
    "cloudscheduler.googleapis.com"
  ]
}

resource "google_project_service" "gcp_services" {
  for_each = toset(var.gcp_service_list)
  project  = "tokyo-house-366821"
  service  = each.key
}

resource "google_project_iam_member" "cloud-storage-pubsub-publishing" {
  project = "tokyo-house-366821"
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-342412401470@gs-project-accounts.iam.gserviceaccount.com"
}

resource "google_service_account" "github-actions-sa" {
  project      = "tokyo-house-366821"
  account_id   = "github-actions-sa"
  display_name = "github-actions-sa"
}

resource "google_project_iam_member" "github-actions-sa-token-generation" {
  project = "tokyo-house-366821"
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${google_service_account.github-actions-sa.email}"
}

resource "google_project_iam_member" "github-actions-sa-cloud-functions-deploy" {
  project = "tokyo-house-366821"
  role    = "roles/cloudfunctions.admin"
  member  = "serviceAccount:${google_service_account.github-actions-sa.email}"
}

data "google_app_engine_default_service_account" "default" {
}

resource "google_service_account_iam_member" "github-actions-sa-act-as-runtime" {
  service_account_id = data.google_app_engine_default_service_account.default.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.github-actions-sa.email}"
}

resource "google_service_account_iam_member" "cloud-build-sa-act-as-runtime" {
  service_account_id = data.google_app_engine_default_service_account.default.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:342412401470@cloudbuild.gserviceaccount.com"
}