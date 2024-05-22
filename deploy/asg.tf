resource "aws_key_pair" "admin" {
  key_name   = "admin"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCcJgoVsO3GT9aUVUZPTQrOydp+DwVagYlE3aEaslLFaIO65R+kit12mYSQ5J7tq7oDaAr9k09h4yl7onJsn16nO4RDoIAds6JjzdK6p9mjlHw2Kn570B3EnttPQk58tGj1936nXO5Vw/vLDzCgpYcCnfGrCBP1C3MoMnZ3Z51zlogSOMSz7DFmQNCDilnhup2cXmC8ORjg2l+WbkROyNpkS5ZXEjtciJ+o41LkyYjwyDnO60zTRKCu3q2eEht/+eCC859EiYelehUQV9qIIOaUnHtMhO5eUoJLGbsTqzknrHDj0Ff+oJPZqIP0SLk9TE1LoSZkZotx0C4L3f/dvqecPtfuagxE5K9TLEa0427/qQxnFvC4rlur3GjoF3EyaXDMdiN8a0/WhkXkDvGuu7RG2FjDy4sSwWAyO7djmRGq+z7lb+lDEjruiyBqGO71Ay7+sOvGiBCWvUI4zMvp3qQf6Yc9Y5YDRfUJ/a9AXQMLsWmiERMunAITWHipHKYgd7U= arian@framework"
}

data "aws_ami" "nixos" {
  owners      = ["427812963091"]
  most_recent = true

  filter {
    name   = "name"
    values = ["nixos/23.11*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}


module "instance_profile_web" {
  source = "./modules/instance_profile"
  name   = "web"
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]
}

data "terraform_remote_state" "bootstrap" {
  backend = "local"
  config = {
    path = "./bootstrap/terraform.tfstate"
  }
}


