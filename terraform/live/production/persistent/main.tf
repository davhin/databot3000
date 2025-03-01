terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.8.0"
    }
  }
}
variable "project_id" {
  type = string
}
variable "region" {
  type = string
}
variable "zone" {
  type = string
}
variable "user_email" {
  type = string
}
variable "billing_account_id" {
  type = string
}

provider "google" {
  project         = var.project_id
  billing_project = var.project_id
  user_project_override = true
}

resource "google_storage_bucket" "prod_data" {
  name          = "${var.project_id}-prod-data"
  project       = var.project_id
  location      = "US"
  storage_class = "STANDARD"

  uniform_bucket_level_access = true
  force_destroy               = false # Prevents accidental deletion

  versioning {
    enabled = true # Keep version history for production data
  }
}

resource "google_storage_bucket" "dev_data" {
  name          = "${var.project_id}-dev-data"
  project       = var.project_id
  location      = "US"
  storage_class = "STANDARD"

  uniform_bucket_level_access = true
  force_destroy               = true # Allow deletion since it's ephemeral

  lifecycle_rule {
    condition {
      age = 90 # Days
    }
    action {
      type = "Delete" # Delete old dev data automatically
    }
  }
}

resource "google_storage_bucket" "archive" {
  name          = "${var.project_id}-archive"
  project       = var.project_id
  location      = "US"
  storage_class = "COLDLINE"

  uniform_bucket_level_access = true
  force_destroy               = false

  lifecycle_rule {
    condition {
      age = 365 # Days
    }
    action {
      type          = "SetStorageClass"
      storage_class = "ARCHIVE" # Move very old data to archive storage
    }
  }
}

# Output the bucket names
output "prod_bucket" {
  value = google_storage_bucket.prod_data.name
}

output "dev_bucket" {
  value = google_storage_bucket.dev_data.name
}

output "archive_bucket" {
  value = google_storage_bucket.archive.name
}

# First, create the budget resource
resource "google_billing_budget" "budget" {
  billing_account = var.billing_account_id # Replace with your billing account ID
  display_name    = "Monthly Cost Budget"

  budget_filter {
    projects = ["projects/${var.project_id}"] # Optional: specify project(s)
  }

  amount {
    specified_amount {
      currency_code = "EUR" # Or "USD" for dollars
      units         = "20"
    }
  }

  threshold_rules {
    threshold_percent = 1.0 # 100% of the budget
    spend_basis       = "CURRENT_SPEND"
  }

  all_updates_rule {
    monitoring_notification_channels = [
      google_monitoring_notification_channel.email.id
    ]
    disable_default_iam_recipients = true
  }
}

# Create the email notification channel
resource "google_monitoring_notification_channel" "email" {
  display_name = "Budget Alert Email"
  project      = var.project_id
  type         = "email"

  labels = {
    email_address = "${var.user_email}"
  }
}
