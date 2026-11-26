<p align="left">
  <img width="200" alt="Aster" src="https://github.com/user-attachments/assets/a337e975-996d-4672-a92b-b809591f389a" />
</p>

[![CI](https://github.com/Aster-Privacy/Aster-Nix/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Aster-Privacy/Aster-Nix/actions/workflows/ci.yml)
[![CodeQL](https://github.com/Aster-Privacy/Aster-Nix/actions/workflows/codeql.yml/badge.svg?branch=main)](https://github.com/Aster-Privacy/Aster-Nix/actions/workflows/codeql.yml)
[![Package updates](https://github.com/Aster-Privacy/Aster-Nix/actions/workflows/update.yml/badge.svg?branch=main)](https://github.com/Aster-Privacy/Aster-Nix/actions/workflows/update.yml)
[![Nix flake](https://img.shields.io/badge/Nix-flake-5277C3?logo=nixos&logoColor=white)](https://wiki.nixos.org/wiki/Flakes)
[![License: AGPL v3](https://img.shields.io/badge/license-AGPL--3.0-blue)](LICENSE)

Aster for Nix packages Aster Mail and Aster Bridge for NixOS and any Linux system that runs Nix. Each package installs the same signed Linux build that we publish on GitHub, and it's pinned by its hash, so Nix refuses any file that doesn't match the release.

You can sign up at [aster.cx](https://aster.cx). A phone number and recovery email are not required.

## How it works

Nix keeps the apps up to date. Every six hours, a workflow in this repository checks for new releases, updates the versions and hashes, and merges the change after the builds pass. Before it accepts a release, it checks the GitHub build attestation on every file, which proves the file was built by that release's own workflow from the tagged source. If any file fails this check, the update stops. A new release usually reaches this flake within a few hours of shipping.

In Aster Mail versions after 1.4.89 and Aster Bridge versions after 1.0.18, the updater built into each app turns off when Nix installs it. Earlier versions can still tell you that an update is available. Install updates through Nix rather than from the app, because Nix doesn't manage a copy that the app installs itself. To stop these notices in Aster Mail, go to **Settings > Updates** and turn off **Check for updates automatically**.

The flake also includes a NixOS module and a Home Manager module that run Aster Bridge in the background, so your mail client can connect to it without the desktop app open.

## Getting started

To try an app without installing it, run it straight from the flake:

```bash
nix run github:Aster-Privacy/Aster-Nix#aster-mail
nix run github:Aster-Privacy/Aster-Nix#aster-bridge
nix run github:Aster-Privacy/Aster-Nix#aster-bridge-cli -- --help
```

To install the apps, add the flake to your inputs:

```nix
inputs.aster.url = "github:Aster-Privacy/Aster-Nix";
```

Then add its overlay and the apps you want to your configuration:

```nix
nixpkgs.overlays = [ aster.overlays.default ];
environment.systemPackages = [ pkgs.aster-mail pkgs.aster-bridge ];
```

## Running Aster Bridge in the background

To run Aster Bridge as a service, import the module and turn it on:

```nix
imports = [ aster.nixosModules.aster-bridge ];
services.aster-bridge.enable = true;
```

Sign in once with `aster-bridge login`, and then restart the service with `systemctl --user restart aster-bridge`. If you use Home Manager, import `aster.homeManagerModules.aster-bridge` instead. You can find every option in [`modules/bridge-options.nix`](modules/bridge-options.nix).

## Community

Join our [Discord](https://discord.gg/R4XqRUfgWZ) to share feedback, ask questions, and contribute to the privacy community. You can also find us on [X](https://x.com/AsterPrivacy) and [Reddit](https://www.reddit.com/r/AsterPrivacy).

If you have any questions or security disclosures, email us at [hello@astermail.org](mailto:hello@astermail.org) or [security@astermail.org](mailto:security@astermail.org). **Do not open a public issue for security vulnerabilities.** Read [SECURITY.md](SECURITY.md) for the full security vulnerability disclosure process.

## Contributing

We welcome contributions of all kinds. Read [CONTRIBUTING.md](https://github.com/Aster-Privacy/.github/blob/main/CONTRIBUTING.md) before opening a pull request.

By contributing to any Aster repository, you agree that your contributions will be licensed under [AGPL v3](https://www.gnu.org/licenses/agpl-3.0.en.html).
