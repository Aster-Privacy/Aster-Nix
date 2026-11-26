{ self, pkgs }:

let
  inherit (self.inputs.nixpkgs) lib;
  system = pkgs.stdenv.hostPlatform.system;

  evaluate =
    bridge:
    lib.nixosSystem {
      inherit system;
      modules = [
        self.nixosModules.aster-bridge
        {
          boot.loader.grub.enable = false;
          fileSystems."/" = {
            device = "nodev";
            fsType = "tmpfs";
          };
          system.stateVersion = "25.11";
          services.aster-bridge = {
            enable = true;
          }
          // bridge;
        }
      ];
    };

  failed_assertions =
    bridge:
    let
      cfg = (evaluate bridge).config.services.aster-bridge;
    in
    map (a: a.message) (
      lib.filter (a: !a.assertion) (import ../modules/bridge-service.nix { inherit lib cfg; }).assertions
    );

  rejects =
    bridge: fragment:
    lib.assertMsg (lib.any (lib.hasInfix fragment) (failed_assertions bridge)) "expected the module to reject: ${fragment}";

  evaluated = evaluate {
    listen = "0.0.0.0";
    allowFrom = [
      "192.168.1.0/24"
      "10.0.0.0/8"
    ];
    hostnames = [ "bridge.home.arpa" ];
    secretKeyFile = "/run/secrets/aster-bridge.key";
  };

  unit = evaluated.config.systemd.user.units."aster-bridge.service".text;
in
assert
  failed_assertions {
    listen = "0.0.0.0";
    secretKeyFile = "/run/secrets/aster-bridge.key";
  } == [ ];
assert rejects { secretKeyFile = "${builtins.storeDir}/aster-bridge.key"; } "secretKeyFile";
assert rejects {
  tlsCertFile = "/run/secrets/cert.pem";
  tlsKeyFile = "${builtins.storeDir}/key.pem";
} "tlsKeyFile";
assert rejects { tlsCertFile = "/run/secrets/cert.pem"; } "both tlsCertFile and tlsKeyFile";
assert rejects { allowFrom = [ "192.168.1.0/24" ]; } "only apply when listen is set";
assert rejects { hostnames = [ "bridge.home.arpa" ]; } "only apply when listen is set";
pkgs.runCommand "aster-bridge-nixos-module-check"
  {
    inherit unit;
    passAsFile = [ "unit" ];
  }
  ''
    check() {
      grep -qF -- "$1" "$unitPath" || { echo "missing from unit: $1"; cat "$unitPath"; exit 1; }
    }
    check "serve --service"
    check "ASTER_BRIDGE_LISTEN=0.0.0.0"
    check "ASTER_BRIDGE_ALLOW_FROM=192.168.1.0/24,10.0.0.0/8"
    check "ASTER_BRIDGE_HOSTNAMES=bridge.home.arpa"
    check "ASTER_BRIDGE_SECRET_BACKEND=file"
    check "ASTER_BRIDGE_SECRET_KEY_FILE=/run/secrets/aster-bridge.key"
    check "RestartPreventExitStatus=2 3 4 5 6 7"
    check "WantedBy=default.target"
    touch $out
  ''
