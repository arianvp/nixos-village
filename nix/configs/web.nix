{ pkgs, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/amazon-image.nix")
  ];


  services.nginx = {
    defaultListenAddresses = [ "0.0.0.0" ];
    enable = true;
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
  system.stateVersion = "24.05";

}
