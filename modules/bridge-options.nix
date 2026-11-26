{ lib, default_package }:

{
  enable = lib.mkEnableOption "Aster Bridge, the headless bridge that serves Aster Mail over IMAP, SMTP, JMAP, POP3, and CardDAV";

  package = lib.mkOption {
    type = lib.types.package;
    default = default_package;
    defaultText = lib.literalExpression "aster-nix.packages.\${system}.aster-bridge-cli";
    description = "The Aster Bridge CLI package to run.";
  };

  dataDir = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "%h/.local/share/aster-bridge";
    description = ''
      Folder that stores the account, cache, and settings. When null, the bridge uses its default folder.
      Systemd specifiers such as `%h` are expanded.
    '';
  };

  listen = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "0.0.0.0";
    description = "Address the mail servers listen on. When null, the bridge listens on 127.0.0.1 only.";
  };

  allowFrom = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    example = [ "192.168.1.0/24" ];
    description = "Addresses or CIDR ranges that can connect when `listen` accepts connections from other devices. When empty, the bridge accepts private network ranges only.";
  };

  hostnames = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    example = [ "bridge.home.arpa" ];
    description = "Host names that mail apps use to reach this bridge.";
  };

  secretKeyFile = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "/run/secrets/aster-bridge.key";
    description = ''
      Path to a key file that encrypts the bridge's stored keys. Set this on machines without a desktop keyring.
      Create the key with `aster-bridge secret-key create` while `ASTER_BRIDGE_SECRET_KEY_FILE` points at this path.
      The path must not be in the Nix store.
    '';
  };

  tlsCertFile = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "PEM certificate chain to serve instead of the generated certificate. Requires `tlsKeyFile`.";
  };

  tlsKeyFile = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "PEM private key for `tlsCertFile`. The path must not be in the Nix store.";
  };
}
