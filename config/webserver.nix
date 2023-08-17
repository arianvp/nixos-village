{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/amazon-image.nix")
  ];
  services.ssm-agent.enable = true;
  services.nginx.enable = true;
  system.stateVersion = "23.05";
}
