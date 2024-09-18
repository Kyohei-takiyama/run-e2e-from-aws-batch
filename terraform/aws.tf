terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = "takisuke-terraform-state-bucket"
    key    = "aws-batch/terraform.tfstate"
    region = "us-west-2"
  }
}

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_accsess_key
  secret_key = var.aws_secret_key
}
