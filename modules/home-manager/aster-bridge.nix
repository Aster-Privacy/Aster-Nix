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

    home.packages = [ cfg.package ];

    systemd.user.services.aster-bridge = {
      Unit = {
        Description = "Aster Bridge";
        Documentation = [ "https://github.com/Aster-Privacy/Aster-Bridge" ];
      };
      Service = service.serviceConfig // {
        Environment = lib.mapAttrsToList (name: value: "${name}=${value}") service.environment;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
