terraform {
  required_version = "~> 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.41.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket         = "nixos-village-terraform20240316094340583200000001"
    region         = "eu-central-1"
    key            = "terraform.tfstate"
    dynamodb_table = "nixos-village-terraform"
  }
}

provider "aws" {
  region = "eu-central-1"
  default_tags {
    tags = {
      ManagedBy   = "terraform"
      GithubOwner = "arianvp"
      GithubRepo  = "nixos-village"
    }
  }
}

provider "github" {
  owner = "arianvp"
}
