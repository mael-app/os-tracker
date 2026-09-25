{
  description = "Lightweight daemon to track active OS in real time";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: rec {
        os-tracker = pkgs.callPackage ./nix/package.nix { };
        default = os-tracker;
      });

      # For configurations that prefer pkgs.os-tracker over the flake output.
      overlays.default = final: _prev: {
        os-tracker = final.callPackage ./nix/package.nix { };
      };

      # Declares services.os-tracker, which runs the daemon as a systemd user
      # service. homeManagerModules is the older name for the same module.
      homeModules.default = import ./nix/home-module.nix self;
      homeManagerModules = self.homeModules;

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.cargo
            pkgs.rustc
            pkgs.clippy
            pkgs.rustfmt
            pkgs.rust-analyzer
          ];
        };
      });

      checks = forAllSystems (pkgs: {
        inherit (self.packages.${pkgs.stdenv.hostPlatform.system}) os-tracker;
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);
    };
}
