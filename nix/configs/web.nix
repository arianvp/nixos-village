{ pkgs, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/amazon-image.nix")
  ];

  services.nginx = {
    enable = true;
    virtualHosts.localhost = { };
  };

  services.getty.autologinUser = "root";

  # services.journald.console = "/dev/ttyS0";

  networking.firewall.allowedTCPPorts = [ 80 443 ];
  system.stateVersion = "24.05";
}
