resource "aws_ssm_document" "nixos_rollback" {
  name          = "NixOS-Rollback"
  document_type = "Command"
  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Rollback NixOS the previous generation."
    parameters = {
      description = "Whether to switch or reboot to rollback."
      action = {
        type          = "String"
        allowedValues = ["switch", "reboot"]
        default       = "switch"
      }
      profile = {
        type        = "String"
        description = "The profile to use. By default uses the system profile"
        default     = "/nix/var/nix/profiles/system"
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
        description   = "Whether to switch or reboot to deploy."
        allowedValues = ["switch", "reboot"]
        default       = "switch"
      }
      profile = {
        type    = "String"
        default = "/nix/var/nix/profiles/system"
      }
      installable = {
        type        = "String"
        description = <<-EOF
        The NixOS configuration to deploy. Can either be a flake output
        attribute or a store path.  When a flake output attribute is used, the
        flake is evaluated on the machine. Evaluation NixOS configurations takes
        quite a bit of RAM so this might not work on small instances.

        You can also provide a pre-built store path. In that case no evaluation
        is done on the machine and the configuration is deployed as is. You
        should probably set the `substituters` and `trustedPublicKeys`
        parameters in that case so that your prebuilt store path can be fetched
        from  the cache.
        EOF

      }
      substituters = {
        type        = "String"
        description = "The substituters to use."
        default     = ""
      }
      trustedPublicKeys = {
        type    = "String"
        default = "The key with which to verify the substituters."
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
