resource "aws_key_pair" "admin" {
  key_name   = "admin"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCcJgoVsO3GT9aUVUZPTQrOydp+DwVagYlE3aEaslLFaIO65R+kit12mYSQ5J7tq7oDaAr9k09h4yl7onJsn16nO4RDoIAds6JjzdK6p9mjlHw2Kn570B3EnttPQk58tGj1936nXO5Vw/vLDzCgpYcCnfGrCBP1C3MoMnZ3Z51zlogSOMSz7DFmQNCDilnhup2cXmC8ORjg2l+WbkROyNpkS5ZXEjtciJ+o41LkyYjwyDnO60zTRKCu3q2eEht/+eCC859EiYelehUQV9qIIOaUnHtMhO5eUoJLGbsTqzknrHDj0Ff+oJPZqIP0SLk9TE1LoSZkZotx0C4L3f/dvqecPtfuagxE5K9TLEa0427/qQxnFvC4rlur3GjoF3EyaXDMdiN8a0/WhkXkDvGuu7RG2FjDy4sSwWAyO7djmRGq+z7lb+lDEjruiyBqGO71Ay7+sOvGiBCWvUI4zMvp3qQf6Yc9Y5YDRfUJ/a9AXQMLsWmiERMunAITWHipHKYgd7U= arian@framework"
}

resource "aws_key_pair" "utm" {
  key_name   = "utm"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICILdRig9yBu9SLpJQxhSW13yMXsshKibyeeQHUQZwg/ arian@utm"
}


data "aws_ami" "nixos" {
  most_recent = true
  owners      = ["427812963091"]
  filter {
    name   = "name"
    values = ["nixos/24.05beta*"]
  }
  filter {
    name   = "architecture"
    values = ["arm64"]
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

module "ssm_documents" {
  source = "./modules/ssm_documents"
}

resource "aws_instance" "web" {
  count                = 2
  ami                  = data.aws_ami.nixos.id
  instance_type        = "t4g.medium"
  key_name             = aws_key_pair.utm.key_name
  iam_instance_profile = module.instance_profile_web.name
  tags = {
    Name = "web"
  }
}
