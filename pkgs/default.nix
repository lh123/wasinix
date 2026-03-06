{ system, nixpkgs }:
let
  pkgs = import nixpkgs { inherit system; };
  toolchainPkgs = import ./toolchain { inherit pkgs; };

  toolchainEnv = rec {
    buildCc = "${pkgs.buildPackages.stdenv.cc}/bin/cc";
    host = "wasm32-wasix";
    crossSystem = {
      # Keep nixpkgs parser-compatible triple and pin WASIX tooling explicitly.
      config = "wasm32-unknown-wasi";
      useLLVM = true;
      isWasix = true;
    };

    toolchainEnv = ''
      export WASIXCC_LLVM_LOCATION="${toolchainPkgs.wasixLlvm}/bin"
      export WASIXCC_SYSROOT_PREFIX="${toolchainPkgs.wasixSysroot}"
      export WASIXCC_BINARYEN_LOCATION="${toolchainPkgs.binaryen}/bin"
      export WASIXCC_AUTOCONF_WORKAROUNDS=yes
    '';

    ccEnv = ''
      export CC=wasixcc
      export CXX=wasix++
      export LD=wasixld
      export AR=wasixar
      export NM=wasixnm
      export RANLIB=wasixranlib
      export WASIXCC_RUN_WASM_OPT=no
    '';

    commonPreConfigure = ''
      export PATH="${toolchainPkgs.wasixcc}/bin:$PATH"
      ${toolchainEnv}
      ${ccEnv}
    '';
  };
  toolchain = toolchainPkgs // toolchainEnv;

  pkgsCross = import nixpkgs {
    inherit system;
    crossSystem = toolchainEnv.crossSystem;
  };

  libraries = import ./libraries {
    nixpkgs = nixpkgs;
    inherit pkgs pkgsCross;
    inherit toolchain;
  };

  programs = import ./programs {
    nixpkgs = nixpkgs;
    inherit pkgs pkgsCross libraries;
    inherit toolchain;
  };

  makeWasmerPackage = pkgs.callPackage ./wasmer/make-wasmer-package.nix { };
  makePlainWasmerPackage = pkgs.callPackage ./wasmer/make-plain-wasmer-package.nix { };

  nanoWasmer = pkgs.callPackage ./programs/nano/nanoWasmer.nix {
    inherit makeWasmerPackage;
    nano = programs.nano;
  };
  grepWasmer = pkgs.callPackage ./programs/grep/grepWasmer.nix {
    inherit makeWasmerPackage;
    grep = programs.grep;
  };
  sedWasmer = pkgs.callPackage ./programs/sed/sedWasmer.nix {
    inherit makeWasmerPackage;
    sed = programs.sed;
  };
  findWasmer = pkgs.callPackage ./programs/find/findWasmer.nix {
    inherit makeWasmerPackage;
    find = programs.find;
  };
  gzipWasmer = pkgs.callPackage ./programs/gzip/gzipWasmer.nix {
    inherit makeWasmerPackage;
    gzip = programs.gzip;
  };
  tarWasmer = pkgs.callPackage ./programs/tar/tarWasmer.nix {
    inherit makeWasmerPackage;
    tar = programs.tar;
  };
  lessWasmer = pkgs.callPackage ./programs/less/lessWasmer.nix {
    inherit makeWasmerPackage;
    less = programs.less;
  };
  ncursesWasmer = pkgs.callPackage ./programs/ncurses/ncursesWasmer.nix {
    inherit makeWasmerPackage;
    ncurses = programs.ncurses;
  };
  crabsayWasmer = pkgs.callPackage ./programs/crabsay/crabsayWasmer.nix {
    inherit makeWasmerPackage;
    crabsay = programs.crabsay;
  };
  phpixPhp83Wasmer = pkgs.callPackage ./programs/phpix/phpixPhp83Wasmer.nix {
    inherit makeWasmerPackage;
    phpixPhp83 = programs.phpixPhp83;
  };

  cliPlatformWasmer = pkgs.callPackage ./wasmer/cli-platform.nix {
    inherit makePlainWasmerPackage;
  };

  wasmer = import ./wasmer {
    inherit (pkgs) lib;
    inherit pkgs nanoWasmer grepWasmer sedWasmer findWasmer gzipWasmer tarWasmer lessWasmer ncursesWasmer crabsayWasmer phpixPhp83Wasmer cliPlatformWasmer;
  };

  allPackages = libraries // programs;
  allWasmPackages = pkgs.lib.removeAttrs allPackages [ "phpixPhp83" ];

  allWasm = pkgs.runCommand "wasix-all-wasm" { } ''
    mkdir -p "$out/bin"
    ${pkgs.lib.concatMapStringsSep "\n" (name: ''
      if [ -d "${allWasmPackages.${name}}/bin" ]; then
        ${pkgs.findutils}/bin/find "${allWasmPackages.${name}}/bin" -maxdepth 1 -type f -name '*.wasm' \
          -exec ${pkgs.coreutils}/bin/cp -f '{}' "$out/bin/" \;
      fi
    '') (builtins.attrNames allWasmPackages)}
  '';
in
{
  inherit pkgs pkgsCross toolchain libraries programs wasmer allPackages allWasm;
  libs = libraries;
}
