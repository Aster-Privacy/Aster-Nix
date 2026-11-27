{ lib, ... }:

{
  name = "aster-bridge";
  meta.maintainers = with lib.maintainers; [ findleyl ];

  nodes.machine = {
    users.users.alice = {
      isNormalUser = true;
      linger = true;
    };

    services.aster-bridge = {
      enable = true;
      dataDir = "%h/.local/share/aster-bridge";
      secretKeyFile = "/home/alice/.config/aster-bridge.key";
    };
  };

  testScript = ''
    user_systemctl = "su - alice -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user {}'"

    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("user@1000.service")

    machine.succeed("aster-bridge --version")

    with subtest("the service waits for sign-in without restarting"):
        try:
            machine.wait_until_succeeds(
                "journalctl -b --no-pager _SYSTEMD_USER_UNIT=aster-bridge.service"
                + " | grep -F 'waiting for you to sign in'",
                timeout=600,
            )
        except Exception:
            print(machine.execute("journalctl -b --no-pager -n 200")[1])
            raise
        machine.succeed(
            user_systemctl.format("show aster-bridge.service -p ActiveState") + " | grep -Fx ActiveState=active"
        )
        machine.succeed(
            user_systemctl.format("show aster-bridge.service -p NRestarts") + " | grep -Fx NRestarts=0"
        )
  '';
}
