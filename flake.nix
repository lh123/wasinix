{
  description = "WASIX package repository";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    self.submodules = true;
  };

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      wasix = import ./pkgs {
        inherit system nixpkgs;
      };

    in {
      wasix = {
        inherit (wasix.toolchain) wasixcc;
        cargo-wasix = wasix.toolchain.cargoWasix;
        wasix-rust-toolchain = wasix.toolchain.wasixRustToolchain;
        inherit (wasix.libraries) ncursesLib php83ZTS php85ZTS;
        inherit (wasix.programs) nano grep sed find gzip tar less ncurses crabsay phpixPhp83;
      };

      wasmer = wasix.wasmer.packages;
      legacyPackages.${system} = {
        pkgsCross = {
          wasix = wasix.pkgsCross;
        };
      };

      devShells.${system}.default = wasix.pkgs.mkShell {
        packages = [
          wasix.toolchain.wasixcc
          wasix.toolchain.cargoWasix
          wasix.libraries.ncursesLib
          wasix.pkgs.gnumake
          wasix.pkgs.pkg-config
        ];
        shellHook = ''
          ${wasix.toolchain.toolchainEnv}
          ${wasix.toolchain.ccEnv}
          echo "WASIX shell ready. Build with: nix build"
        '';
      };

      packages.${system} =
        {
          wasixAll = wasix.allWasm;
          wasmerAll = wasix.wasmer.allWasmer;
          default = wasix.allWasm;

          cargo-wasix = wasix.toolchain.cargoWasix;
          wasixcc = wasix.toolchain.wasixcc;
          php83ZTS = wasix.libraries.php83ZTS;
          php85ZTS = wasix.libraries.php85ZTS;
          phpixPhp83 = wasix.programs.phpixPhp83;
        };
    };
}
