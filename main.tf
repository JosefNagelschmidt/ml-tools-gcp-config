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

resource "google_storage_bucket" "city-population-grids" {
  name          = "bucket-city-population-grids"
  force_destroy = false
  location      = "us-west1"
  storage_class = "STANDARD"
}

resource "google_storage_bucket" "general-configs" {
  name          = "bucket-general-config-files"
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
    "cloudscheduler.googleapis.com",
    "distance-matrix-backend.googleapis.com",
    "apikeys.googleapis.com"
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

resource "google_pubsub_topic" "pubsub-topic-google-directions-trigger" {
  name = "pubsub-topic-google-directions-trigger"
  message_storage_policy {
    allowed_persistence_regions = [
      "us-west1",
    ]
  }
  message_retention_duration = "86600s"
}

resource "google_bigquery_dataset" "dataset_journey" {
  dataset_id  = "dataset_journey"
  description = "Dataset consisting of journeys between two points."
  location    = "us-west1"
}

resource "google_bigquery_table" "journey_durations" {
  dataset_id = google_bigquery_dataset.dataset_journey.dataset_id
  table_id   = "journey_durations"

  time_partitioning {
    type                     = "DAY"
    field                    = "id_origin"
    require_partition_filter = true
  }

  schema = <<EOF
[
  {
    "name": "id_origin",
    "type": "TIMESTAMP",
    "mode": "REQUIRED",
    "description": "Foreign key of origin for metadata table, generated from timestamp"
  },
  {
    "name": "id_destination",
    "type": "TIMESTAMP",
    "mode": "REQUIRED",
    "description": "Foreign key of destination for metadata table, generated from timestamp"
  },
  {
    "name": "driving_duration_in_s",
    "type": "INT64",
    "mode": "NULLABLE",
    "description": "Driving duration in seconds"
  },
  {
    "name": "transit_duration_in_s",
    "type": "INT64",
    "mode": "NULLABLE",
    "description": "Transit duration in seconds"
  },
  {
    "name": "bicycling_duration_in_s",
    "type": "INT64",
    "mode": "NULLABLE",
    "description": "Cycling duration in seconds"
  },
  {
    "name": "driving_distance_in_m",
    "type": "INT64",
    "mode": "NULLABLE",
    "description": "Driving distance in meter"
  },
  {
    "name": "transit_distance_in_m",
    "type": "INT64",
    "mode": "NULLABLE",
    "description": "Transit distance in meter"
  },
  {
    "name": "bicycling_distance_in_m",
    "type": "INT64",
    "mode": "NULLABLE",
    "description": "Cycling distance in meter"
  }
]
EOF
}

resource "google_bigquery_table" "journey_metadata" {
  dataset_id = google_bigquery_dataset.dataset_journey.dataset_id
  table_id   = "journey_metadata"

  time_partitioning {
    type                     = "DAY"
    field                    = "id"
    require_partition_filter = true
  }

  schema = <<EOF
[
  {
    "name": "id",
    "type": "TIMESTAMP",
    "mode": "REQUIRED",
    "description": "Primary key, reflecting time of generation"
  },
  {
    "name": "type",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "Origin or destination of journey"
  },
  {
    "name": "house_number",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "House number"
  },
  {
    "name": "road",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "Road"
  },
  {
    "name": "neighbourhood",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "Neighbourhood"
  },
  {
    "name": "suburb",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "Suburb"
  },
  {
    "name": "city_district",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "City district"
  },
  {
    "name": "city",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "City"
  },
  {
    "name": "state",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "State"
  },
  {
    "name": "postcode",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "Postcode"
  },
  {
    "name": "country",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "Country"
  },
  {
    "name": "country_code",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "Country code"
  }
]
EOF
}


# resource "google_cloud_scheduler_job" "google-directions-cron-job" {
#   name        = "google-directions-cron-job"
#   description = "google-directions-cron-job"
#   schedule    = "* * * * *"

#   pubsub_target {
#     # topic.id is the topic's full resource name.
#     topic_name = google_pubsub_topic.pubsub-topic-google-directions-trigger.id
#     data       = base64encode("test")
#   }
# }