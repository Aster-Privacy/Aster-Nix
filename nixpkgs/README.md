# nixpkgs packages

This directory holds the Aster Mail and Aster Bridge packages as they're written for [nixpkgs](https://github.com/NixOS/nixpkgs). Unlike the flake in this repository, which installs the signed release builds, these packages build every app from its tagged source.

- `pkgs/by-name/as/` has the `aster-mail`, `aster-bridge`, and `aster-bridge-cli` packages.
- `nixos/` has the `services.aster-bridge` module and its NixOS test.
- `scripts/apply.sh` adds the packages, the module, the test, and the maintainer entry to a nixpkgs checkout.

## How it stays current

The `nixpkgs` workflow adds these files to the latest `nixos-unstable` and builds all three packages from source on x86_64 and aarch64 Linux. It also runs the NixOS test, checks the formatting, and checks the package metadata.

Every six hours, the `nixpkgs_update` workflow checks for new Aster Mail and Aster Bridge releases. Before it accepts one, it confirms that the release tag points to a signed commit on `main` and that the source hash matches that exact commit. It checks the pinned `aster-crypto` and `aster-ui` commits the same way. A separate job then confirms that the update only changes versions, hashes, and pinned commits before it opens a pull request, which merges after the builds pass.

To try the packages in your own nixpkgs checkout, run:

```bash
nixpkgs/scripts/apply.sh /path/to/nixpkgs
cd /path/to/nixpkgs
nix-build -A aster-mail -A aster-bridge -A aster-bridge-cli
nix-build -A nixosTests.aster-bridge
```
