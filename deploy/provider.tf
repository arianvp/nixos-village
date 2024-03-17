terraform {
  backend "s3" {
    bucket = "arn:aws:s3:::nixos-village-terraform20240316094340583200000001"
    region = "eu-central-1"
    key = "terraform.tfstate"
  }
}

provider "aws" {
  region = "eu-central-1"
}
