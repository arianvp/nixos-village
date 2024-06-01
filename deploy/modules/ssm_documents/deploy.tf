resource "aws_ssm_document" "nixos_rollback" {
  name          = "NixOS-Rollback"
  document_type = "Command"
  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Rollback NixOS"
    parameters = {
      profile = {
        type    = "String"
        default = "/nix/var/nix/profiles/system"
      }
    }
    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "rollback"
        inputs = { runCommand = [file("${path.module}/rollback.sh")] }
      }
    ]
  }) 
}

resource "aws_ssm_document" "nixos_deploy" {
  name          = "NixOS-Deploy"
  document_type = "Command"
  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Deploy NixOS"
    parameters = {
      action = {
        type          = "String"
        allowedValues = ["switch", "reboot"]
        default       = "switch"
      }
      profile = {
        type    = "String"
        default = "/nix/var/nix/profiles/system"
      }
      installable = {
        type = "String"
      }
      substituters = {
        type    = "String"
        default = ""
      }
      trustedPublicKeys = {
        type    = "String"
        default = ""
      }
    }
    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "deploy"
        inputs = { runCommand = [file("${path.module}/deploy.sh")] }
      }
    ]
  })
}
