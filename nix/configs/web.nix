{ pkgs, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/amazon-image.nix")
  ];


  services.nginx = {
    enable = true;
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
  system.stateVersion = "24.05";

}
