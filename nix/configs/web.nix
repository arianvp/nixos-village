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

  users.users.root.initialHashedPassword = "$y$j9T$sTq5/5v8FYMgdBNN8dWny0$wkGYT3Jv.UGxteor8V7CL99v6OFtHqqmrhEOGlYs.53";

  # services.journald.console = "/dev/ttyS0";

  networking.firewall.allowedTCPPorts = [ 80 443 ];
  system.stateVersion = "24.05";
}
