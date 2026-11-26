{ lib, cfg }:

let
  optional_env =
    name: value:
    lib.optionalAttrs (value != null && value != [ ]) {
      ${name} = if builtins.isList value then lib.concatStringsSep "," value else value;
    };
in
{
  assertions = [
    {
      assertion = (cfg.tlsCertFile == null) == (cfg.tlsKeyFile == null);
      message = "Aster Bridge: set both tlsCertFile and tlsKeyFile, or neither.";
    }
    {
      assertion = cfg.listen != null || (cfg.allowFrom == [ ] && cfg.hostnames == [ ]);
      message = "Aster Bridge: allowFrom and hostnames only apply when listen is set.";
    }
  ]
  ++
    map
      (name: {
        assertion = cfg.${name} == null || !lib.hasPrefix builtins.storeDir cfg.${name};
        message = "Aster Bridge: ${name} must not be in the Nix store, where every user can read it.";
      })
      [
        "secretKeyFile"
        "tlsKeyFile"
      ];

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
}
