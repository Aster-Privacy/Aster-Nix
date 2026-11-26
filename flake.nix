{
  description = "Aster Mail, Aster Bridge, and the Aster Bridge CLI for Nix and NixOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      for_all_systems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      package_names = [
        "aster-mail"
        "aster-bridge"
        "aster-bridge-cli"
      ];

      build_packages =
        pkgs:
        lib.genAttrs package_names (
          name: pkgs.callPackage ./pkgs/by-name/${builtins.substring 0 2 name}/${name}/package.nix { }
        );
    in
    {
      overlays.default = final: _prev: build_packages final;

      packages = for_all_systems (
        pkgs:
        let
          aster = build_packages pkgs;
        in
        aster // { default = aster.aster-mail; }
      );

      nixosModules = {
        aster-bridge = import ./modules/nixos/aster-bridge.nix self;
        default = self.nixosModules.aster-bridge;
      };

      homeManagerModules = {
        aster-bridge = import ./modules/home-manager/aster-bridge.nix self;
        default = self.homeManagerModules.aster-bridge;
      };

      checks = for_all_systems (
        pkgs:
        self.packages.${pkgs.stdenv.hostPlatform.system}
        // {
          nixos-module = import ./tests/nixos-module.nix { inherit self pkgs; };
        }
      );

      formatter = for_all_systems (pkgs: pkgs.nixfmt-tree);
    };
}
