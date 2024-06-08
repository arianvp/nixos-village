{ lib, pkgs, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/amazon-image.nix")
    ../modules/fluent-bit.nix
    ../mixins/aws.nix
  ];


  services.getty.autologinUser = "root";

  services.fluent-bit = {
    enable = true;
    settings.pipeline.inputs = [{
      name = "systemd";
      db = "\${STATE_DIRECTORY}/systemd.db";
      tag = "host.*";
    }];
  };

  systemd.services.web = {
    enable = false;
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
