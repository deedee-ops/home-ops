resource "b2_bucket" "backup" {
  bucket_name = var.b2_backup_bucket_name
  bucket_type = "allPrivate"

  default_server_side_encryption {
    mode      = "SSE-B2"
    algorithm = "AES256"
  }

  file_lock_configuration {
    is_file_lock_enabled = true

    default_retention {
      mode = "governance"

      period {
        duration = var.b2_backup_retention_days
        unit     = "days"
      }
    }
  }

  lifecycle_rules {
    file_name_prefix                                       = ""
    days_from_hiding_to_deleting                           = var.b2_backup_noncurrent_expiry_days
    days_from_starting_to_canceling_unfinished_large_files = 1
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "b2_application_key" "kopia" {
  key_name   = "kopia-fleet"
  bucket_ids = [b2_bucket.backup.bucket_id]

  # listAllBucketNames and readBuckets exist only for the S3-compatible API, and
  # B2 documents listAllBucketNames as required for a bucket-restricted key used
  # through it. kopia talks S3 via minio-go, so both are load-bearing.
  # bypassGovernance is deliberately absent - that is what makes GOVERNANCE mean
  # anything against a stolen key.
  capabilities = [
    "listBuckets",
    "listAllBucketNames",
    "readBuckets",
    "readBucketEncryption",
    "readBucketRetentions",
    "listFiles",
    "readFiles",
    "writeFiles",
    "deleteFiles",
    "readFileRetentions",
    "writeFileRetentions",
  ]
}

output "b2_backup_bucket_name" {
  description = "Bucket name for the kopiur ClusterRepository and docker/kopia configs"
  value       = b2_bucket.backup.bucket_name
}

output "b2_backup_bucket_id" {
  description = "Bucket ID, for scoping further application keys"
  value       = b2_bucket.backup.bucket_id
}

output "kopia_key_id" {
  description = "Application key ID; goes into kopiur-backblaze-b2-secret and the NAS stack .env"
  value       = b2_application_key.kopia.application_key_id
  sensitive   = true
}

output "kopia_key" {
  description = "Application key; goes into kopiur-backblaze-b2-secret and the NAS stack .env"
  value       = b2_application_key.kopia.application_key
  sensitive   = true
}
