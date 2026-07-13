terraform {
  # Versions configuration
  required_version = "= 1.15.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.54.0"
    }
  }

  # tfstate backend configuration
  backend "s3" {
    bucket  = "terraform-state-infra-common-028365237334-ap-northeast-1-an"
    key     = "terraform.tfstate"
    encrypt = true
    region  = "ap-northeast-1"
  }
}

# Provider configuration
provider "aws" {
  region = "ap-northeast-1"

  default_tags {
    tags = local.default_tags
  }
}