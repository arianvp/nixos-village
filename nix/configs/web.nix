{ lib, pkgs, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/amazon-image.nix")
  ];


  services.getty.autologinUser = "root";

  systemd.services.web = {
    description = "Web server";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      CacheDirectory = "web";
      ExecStart = lib.getExe (pkgs.buildGoModule {
        name = "web";
        src = ./web;
        vendorHash = "sha256-CAr2aNXdt5lHmkidbPvjWZFNXChieeITXy3AMyMoSaI=";
      });
      Restart = "always";
    };
  };

  # services.journald.console = "/dev/ttyS0";

  networking.firewall.allowedTCPPorts = [ 443 ];
  system.stateVersion = "24.05";
}
