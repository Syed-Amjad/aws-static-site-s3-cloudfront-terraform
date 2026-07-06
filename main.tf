# =============================================================================
# CloudHost — main.tf
# Providers + Terraform settings.
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }

  # For a team/production setup you would store state remotely (and lock it):
  #
  # backend "s3" {
  #   bucket       = "my-tf-state-bucket"
  #   key          = "cloudhost/terraform.tfstate"
  #   region       = "us-east-1"
  #   use_lockfile = true          # native S3 state locking (Terraform 1.10+)
  # }
  #
  # Left as the default LOCAL backend here so the project runs with zero setup.
}

# Default provider — used for the S3 origin bucket (may be any region).
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

# CloudFront requires its ACM certificate to live in us-east-1.
# This aliased provider lets us look that certificate up regardless of where the
# bucket lives. (In this project both happen to be us-east-1, but keeping the
# alias makes the code correct even if you move the bucket to another region.)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = var.tags
  }
}
