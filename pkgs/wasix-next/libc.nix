# Foundation (new design, WIP): build the wasix libc FROM SOURCE (just the libc —
# no compiler-rt/libc++/sysroot assembly yet). Base variant only for now.
#
# The libc (musl-based) is independent of the LLVM *sources* — it only needs *a*
# clang to compile — so for this foundation step it builds with nixpkgs'
# llvmPackages_21 (fast, decoupled from the from-source LLVM build). Once that
# foundation lands we point CC at the wasix LLVM instead.
{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  writeText,
  llvmPackages_21,
  gnumake,
  rsync,
  python3,
  cargo,
  rustc,
  coreutils,
}: let
  version = "v2026-02-16.1";

  src = fetchFromGitHub {
    owner = "wasix-org";
    repo = "wasix-libc";
    rev = "4048aab4bc1273868fe84c6d4d179f1e114b95bf"; # tag v2026-02-16.1
    hash = "sha256-PI8Iushd3HS6+tCZ6f4agmz9TIJdL1nxpozWN90ubNY=";
  };

  # witx specs for the header generators (cargo run generate-libc).
  wasiWitx = fetchFromGitHub {
    owner = "WebAssembly";
    repo = "WASI";
    rev = "bac366c8aeb69cacfea6c4c04a503191bf1cede1";
    hash = "sha256-Nj15jrOuBN1VTk8xwSEIJo2a7rr6fLeyYjy0Y/oU178=";
  };
  wasixWitx = fetchFromGitHub {
    owner = "wasix-org";
    repo = "wasix-witx";
    rev = "7295cec42d709e965c7fe9e57faeff23931c9b93";
    hash = "sha256-6sWezkhtrjIlZ9iWujFsiaIqlSVgkzKhfrt7adBELLI=";
  };

  cargoVendor = rustPlatform.importCargoLock {
    lockFile = ./libc-headers.Cargo.lock;
  };
  cargoConfig = writeText "wasix-libc-cargo-config.toml" ''
    [source.crates-io]
    replace-with = "vendored-sources"
    [source.vendored-sources]
    directory = "${cargoVendor}"
  '';
in
  stdenv.mkDerivation {
    pname = "wasix-libc";
    inherit version src;

    nativeBuildInputs = [
      # raw (unwrapped) clang + llvm tools: wasix-libc drives the target itself.
      llvmPackages_21.clang-unwrapped
      llvmPackages_21.llvm
      llvmPackages_21.lld
      gnumake
      rsync
      python3
      cargo
      rustc
      coreutils
    ];

    CARGO_NET_OFFLINE = "true";
    dontConfigure = true;

    postPatch = ''
      rm -rf tools/wasi-headers/WASI tools/wasix-headers/WASI
      cp -r --no-preserve=mode,ownership ${wasiWitx}  tools/wasi-headers/WASI
      cp -r --no-preserve=mode,ownership ${wasixWitx} tools/wasix-headers/WASI
      cp tools/wasix-headers/Cargo.lock tools/wasi-headers/Cargo.lock
      mkdir -p .cargo
      cp ${cargoConfig} .cargo/config.toml
    '';

    buildPhase = ''
      runHook preBuild

      export HOME="$TMPDIR"
      export TARGET_ARCH=wasm32
      export TARGET_OS=wasix
      export CC=clang
      export CXX=clang++
      export NM=llvm-nm
      export AR=llvm-ar
      export RANLIB=llvm-ranlib

      # Regenerate the wasi/wasix api headers (build32-general.sh:prepare_wasix_libc).
      cargo run --manifest-path tools/wasix-headers/Cargo.toml generate-libc
      cp -f libc-bottom-half/headers/public/wasi/api.h libc-bottom-half/headers/public/wasi/api_wasix.h
      sed -i 's|__wasi__|__wasix__|g; s|__wasi_api_h|__wasix_api_h|g' \
        libc-bottom-half/headers/public/wasi/api_wasix.h
      cp -f libc-bottom-half/sources/__wasilibc_real.c libc-bottom-half/sources/__wasixlibc_real.c
      cargo run --manifest-path tools/wasi-headers/Cargo.toml generate-libc
      cp -f libc-bottom-half/headers/public/wasi/api.h libc-bottom-half/headers/public/wasi/api_wasi.h
      printf '#include "api_wasi.h"\n#include "api_wasix.h"\n#include "api_poly.h"\n' \
        > libc-bottom-half/headers/public/wasi/api.h

      # Build the libc only (base variant: plain Makefile, no EH/PIC).
      make CHECK_SYMBOLS=no -j"''${NIX_BUILD_CORES:-4}" -f Makefile
      rm -f sysroot/lib/wasm32-wasi/libc-printscan-long-double.a

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      cp -r sysroot "$out"
      runHook postInstall
    '';

    meta = with lib; {
      description = "WASIX libc (base variant), built from source";
      homepage = "https://github.com/wasix-org/wasix-libc";
      license = with licenses; [asl20 mit];
      platforms = platforms.unix;
    };
  }
