terraform {
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = ">= 2.12"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4"
    }
  }
  required_version = ">= 1.0"
}

# Function resources

data "archive_file" "function" {
  type        = "zip"
  source_file = "${path.module}/handler.py"
  output_path = "${path.module}/function.zip"
}

resource "scaleway_function_namespace" "main" {
  name        = "serverless-examples"
  description = "Serverless examples"
}

resource "scaleway_function" "main" {
  namespace_id = scaleway_function_namespace.main.id
  name         = "python-sqs-trigger-hello-world"
  runtime      = "python311"
  handler      = "handler.handle"
  privacy      = "public"
  zip_file     = data.archive_file.function.output_path
  zip_hash     = data.archive_file.function.output_sha256
  deploy       = true

  min_scale = 0
  max_scale = 1
}

# SQS trigger resources

resource "scaleway_mnq_namespace" "main" {
  name     = "serverless-examples"
  protocol = "sqs_sns"
}

resource "scaleway_mnq_credential" "main" {
  name         = "serverless-examples"
  namespace_id = scaleway_mnq_namespace.main.id
  sqs_sns_credentials {
    permissions {
      can_publish = true
      can_receive = true
      can_manage  = true
    }
  }
}

resource "scaleway_mnq_queue" "main" {
  namespace_id = scaleway_mnq_namespace.main.id
  name         = "python-sqs-trigger-hello-world"

  sqs {
    access_key = scaleway_mnq_credential.main.sqs_sns_credentials.0.access_key
    secret_key = scaleway_mnq_credential.main.sqs_sns_credentials.0.secret_key
  }
}

resource "scaleway_function_trigger" "main" {
  function_id = scaleway_function.main.id
  name        = "my-trigger"
  sqs {
    namespace_id = scaleway_mnq_namespace.main.id
    queue        = scaleway_mnq_queue.main.name
  }
}

# Outputs to send messages to the queue

output "sqs_access_key" {
  value = scaleway_mnq_credential.main.sqs_sns_credentials.0.access_key
}

output "sqs_secret_key" {
  value     = scaleway_mnq_credential.main.sqs_sns_credentials.0.secret_key
  sensitive = true
}

output "sqs_endpoint" {
  value = replace(scaleway_mnq_queue.main.sqs.0.endpoint, "{region}", scaleway_mnq_namespace.main.region)
}

output "sqs_region" {
  value = scaleway_mnq_namespace.main.region
}

output "sqs_queue_url" {
  value = scaleway_mnq_queue.main.sqs.0.url
}
