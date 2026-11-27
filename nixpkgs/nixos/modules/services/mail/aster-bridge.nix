{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.aster-bridge;

  optional_env =
    name: value:
    lib.optionalAttrs (value != null && value != [ ]) {
      ${name} = if builtins.isList value then lib.concatStringsSep "," value else value;
    };
in
{
  options.services.aster-bridge = {
    enable = lib.mkEnableOption "Aster Bridge, which serves Aster Mail to local apps over IMAP, SMTP, JMAP, POP3, and CardDAV";

    package = lib.mkPackageOption pkgs "aster-bridge-cli" { };

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
      description = ''
        Address the mail servers listen on. When null, the bridge listens on 127.0.0.1 only.
        This module never opens firewall ports.
      '';
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
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = (cfg.tlsCertFile == null) == (cfg.tlsKeyFile == null);
        message = "services.aster-bridge: set both tlsCertFile and tlsKeyFile, or neither.";
      }
      {
        assertion = cfg.listen != null || (cfg.allowFrom == [ ] && cfg.hostnames == [ ]);
        message = "services.aster-bridge: allowFrom and hostnames only apply when listen is set.";
      }
    ]
    ++
      map
        (name: {
          assertion = cfg.${name} == null || !lib.hasPrefix builtins.storeDir cfg.${name};
          message = "services.aster-bridge: ${name} must not be in the Nix store, where every user can read it.";
        })
        [
          "secretKeyFile"
          "tlsKeyFile"
        ];

    environment.systemPackages = [ cfg.package ];

    systemd.user.services.aster-bridge = {
      description = "Aster Bridge";
      documentation = [ "https://github.com/Aster-Privacy/Aster-Bridge" ];
      wantedBy = [ "default.target" ];

      environment =
        optional_env "ASTER_BRIDGE_DATA_DIR" cfg.dataDir
        // optional_env "ASTER_BRIDGE_LISTEN" cfg.listen
        // optional_env "ASTER_BRIDGE_ALLOW_FROM" cfg.allowFrom
        // optional_env "ASTER_BRIDGE_HOSTNAMES" cfg.hostnames
        // optional_env "ASTER_BRIDGE_TLS_CERT_FILE" cfg.tlsCertFile
        // optional_env "ASTER_BRIDGE_TLS_KEY_FILE" cfg.tlsKeyFile
        // lib.optionalAttrs (cfg.secretKeyFile != null) {
          ASTER_BRIDGE_SECRET_BACKEND = "file";
          ASTER_BRIDGE_SECRET_KEY_FILE = cfg.secretKeyFile;
        };

      serviceConfig = {
        Type = "simple";
        ExecStart = "${lib.getExe cfg.package} serve --service";
        Restart = "on-failure";
        RestartSec = 10;
        RestartPreventExitStatus = "2 3 4 5 6 7";
        TimeoutStopSec = 30;
        UMask = "0077";
        NoNewPrivileges = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        RestrictNamespaces = true;
        SystemCallArchitectures = "native";
        SystemCallErrorNumber = "EPERM";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
        ];
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
          "AF_NETLINK"
        ];
      };
    };
  };

  meta.maintainers = with lib.maintainers; [ findleyl ];
}
