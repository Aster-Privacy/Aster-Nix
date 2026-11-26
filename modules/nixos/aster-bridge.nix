self:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.aster-bridge;
  service = import ../bridge-service.nix { inherit lib cfg; };
in
{
  options.services.aster-bridge = import ../bridge-options.nix {
    inherit lib;
    default_package = self.packages.${pkgs.stdenv.hostPlatform.system}.aster-bridge-cli;
  };

  config = lib.mkIf cfg.enable {
    inherit (service) assertions;

    environment.systemPackages = [ cfg.package ];

    systemd.user.services.aster-bridge = {
      description = "Aster Bridge";
      documentation = [ "https://github.com/Aster-Privacy/Aster-Bridge" ];
      wantedBy = [ "default.target" ];
      inherit (service) environment serviceConfig;
    };
  };
}
