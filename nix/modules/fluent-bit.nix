{ lib, pkgs, config, ... }:
let
  cfg = config.services.fluent-bit;
  settingsFormat = pkgs.formats.yaml { };
  # TODO: Add check phase
  configYaml = settingsFormat.generate "config.yaml" cfg.settings;
in
{
  options.services.fluent-bit = {
    enable = lib.mkEnableOption "fluent-bit";
    package = lib.mkPackageOption pkgs "fluent-bit" { };
    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = settingsFormat.type;
        options.pipeline = {
          inputs = lib.mkOption { type = lib.types.listOf settingsFormat.type; default = [ ]; };
          filters = lib.mkOption { type = lib.types.listOf settingsFormat.type; default = [ ]; };
          outputs = lib.mkOption { type = lib.types.listOf settingsFormat.type; default = [ ]; };
        };
      };
    };
  };
  config.systemd.services.fluent-bit = {
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${cfg.package}/bin/fluent-bit --config=${configYaml}";
      Restart = "always";
      StateDirectory = "fluent-bit";
      RuntimeDirectory = "fluent-bit";
    };
  };
}
