resource "aws_ssm_document" "nixos_deploy" {
  name          = "NixOS-Deploy"
  document_type = "Command"
  content = jsondecode({
    schemaVersion = "2.2"
    description   = "Deploy NixOS"
    parameters = {
      installable = {
        type        = "String"
      }
      substituters = {
        type        = "String"
      }
      trustedPublicKeys = {
        type        = "String"
      }
    }
    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "deploy"
        inputs = {
          runCommand = [
            "nix-channel --add https://nixos.org/channels/nixos-23.11 nixos",
            "nix-channel --update",
            "nixos-rebuild switch --upgrade",
            "systemctl reboot"
          ]
        }
      }
    ]
  })
}
