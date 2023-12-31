resource "time_static" "time" {}

data "aws_caller_identity" "current" {}

provider "aws" {
  region = var.region

  assume_role {
    role_arn     = "arn:aws:iam::375158168967:role/terraform-state"
    external_id  = "tf-admin"
    session_name = "env-management"
  }
}

locals {
  envs = [
    "dev",
    "prod",
  ]
  tags = {
    Creator      = "Terraform Env Manager"
    Service      = "Terraform Sandbox"
    CreationDate = formatdate("YYYY-MM-DD", time_static.time.rfc3339)
  }
}

terraform {
  backend "s3" {
    role_arn    = "arn:aws:iam::375158168967:role/terraform-state"
    external_id = "tf-admin"

    key            = "main/terraform.tfstate"
    bucket         = "terraform-sandbox-env-manager-state"
    dynamodb_table = "terraform-sandbox-env-manager-state-lock"
    region         = "us-east-2"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_s3_bucket" "this" {
  count = length(local.envs)

  bucket = "${var.project_name}-${element(local.envs, count.index)}-state"
  tags   = merge(local.tags, { Environment = element(local.envs, count.index) })

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_s3_bucket_versioning" "this" {
  count = length(aws_s3_bucket.this)

  bucket = element(aws_s3_bucket.this[*].id, count.index)
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "this" {
  count = var.keep_lock_tables ? length(local.envs) : 0

  name           = "${var.project_name}-${element(local.envs, count.index)}-state-lock"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "LockID"

  tags = merge(local.tags, { Environment = element(local.envs, count.index) })

  attribute {
    name = "LockID"
    type = "S"
  }
}
