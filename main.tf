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
