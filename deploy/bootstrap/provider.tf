terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.41.0"
    }
  }
}

provider "aws" {
  default_tags {
    tags = {
      ManagedBy   = "terraform"
      GithubOwner = "arianvp"
      GithubRepo  = "nixos-village"
    }
  }
}