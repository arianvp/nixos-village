{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/amazon-image.nix")
  ];
  services.ssm-agent.enable = true;
  system.stateVersion = "23.05";
}
