terraform {
  required_version = "<= 1.3.4"

  backend "s3" {
    bucket         = "frame-tf"
    key            = "dev/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "tf-state-locking"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "=4.39.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.4.3"
    }
    github = {
      source  = "integrations/github"
      version = "5.12.0"
    }
  }
}

provider "github" {
  token = var.ghtf # the PAT
  owner = "virbela"
}
