{ pkgs, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/amazon-image.nix")
  ];
  services.amazon-ssm-agent.enable = true;
  services.nginx.enable = true;

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  system.stateVersion = "23.11";


}
