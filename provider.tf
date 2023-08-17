terraform {
  backend "s3" {
    bucket = "nixos-village-terraform20230817154352119700000001"
    region = "eu-central-1"
    key    = "terraform.tfstate"
  }
}

provider "aws" {
  region  = "eu-central-1"
}