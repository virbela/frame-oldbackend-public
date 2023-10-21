terraform {
  ############################################################
  # AFTER RUNNING TERRAFORM APPLY (WITH LOCAL BACKEND)
  # YOU WILL UNCOMMENT THIS CODE THEN RERUN TERRAFORM INIT
  # TO SWITCH FROM LOCAL BACKEND TO REMOTE AWS BACKEND
  ############################################################
  backend "s3" {
    bucket         = "frame-tf" # REPLACE WITH YOUR BUCKET NAME (aws_s3_bucket.bucket)
    key            = "tf-infra/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "tf-state-locking" # match the aws_dynamodb_table.dynamodb_table
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

# This is the code that creates/tracks the infrastructure created
# for the backend block above. You can uncomment the above section
# *after* you've successfully run this portion and then executed
# 'terraform init' to upload the tfstate to the backend
resource "aws_s3_bucket" "tf_state" {
  bucket        = "frame-tf" # REPLACE WITH YOUR BUCKET NAME
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "tf_acl" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# s3 properties
resource "aws_s3_bucket_versioning" "tf_bucket_versioning" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state_crypto_conf" {
  bucket = aws_s3_bucket.tf_state.bucket
  rule {
    bucket_key_enabled = false
    apply_server_side_encryption_by_default { # SSE-S3
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_dynamodb_table" "tf_locks" {
  name         = "tf-state-locking"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}
