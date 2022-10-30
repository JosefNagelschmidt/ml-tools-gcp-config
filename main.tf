terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.5.0"
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
    "eventarc.googleapis.com"
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