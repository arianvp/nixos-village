{ pkgs, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/amazon-image.nix")
  ];
  services.ssm-agent.enable = true;
  # TODO: The upstream nixos module as an .override which causes ssm-agent to always be built from source.
  # This is a bug! And  crashes t3.micro images.
  services.ssm-agent.package = pkgs.ssm-agent;
  services.nginx.enable = true;
  system.stateVersion = "23.05";
}
