# WIP scaffold for the redesigned wasix toolchain, built up in parallel with the
# existing pkgs/toolchain so we can try foundations in isolation.
#
# Design: model wasix as a nixpkgs cross target and lean on nixpkgs' cross
# machinery for the runtimes. All LLVM deviations (the wasix fork source +
# version; later the wasix runtime flags + libc swap) live in one overlay over
# `llvmPackages_21`, so every consumer that asks for `.clang` / `.libcxx` /
# `.compiler-rt` gets the wasix-correct one — no hand-rolled per-runtime drvs.
{
  pkgs,
  nixpkgs,
  system ? "x86_64-linux",
}: let
  # One pinned fork checkout (full monorepo: clang/lld for the toolchain, and
  # compiler-rt/ runtimes/ for the cross runtime builds).
  monorepoSrc = pkgs.fetchFromGitHub {
    owner = "wasix-org";
    repo = "llvm-project";
    rev = "63389e381615454b876e6a24afd878af6cad2b96"; # release tag 21.1.203 (LLVM 21.1.2)
    hash = "sha256-IFQNaJfBTVXWYsahkCGLMbmcs6vWDEwr6xKszq7yHSM=";
  };

  # The single place wasix LLVM deviations live. Uses LLVM's bespoke override
  # (rocm-style): explicit `version` so nixpkgs picks the 21.1.2 patch set, and
  # `officialRelease = {}` + `monorepoSrc`/`src` to swap the source entirely.
  # TODO(next): roll the wasix runtime flags + wasix-libc libc swap in here too,
  # via llvmPackages_21.overrideScope, so .libcxx/.compiler-rt are wasix-correct.
  wasixOverlay = _final: prev: {
    llvmPackages_21 = prev.llvmPackages_21.override (_old: {
      officialRelease = {};
      version = "21.1.2";
      src = monorepoSrc;
      inherit monorepoSrc;
      doCheck = false;
    });
    # Swap the cross libc: wasix-libc instead of nixpkgs' wasilibc, so the cross
    # stdenv (and the runtimes built against it) see the wasix headers/libs.
    wasilibc = libc;
  };

  # Cross pkgs for wasm32-wasix, with the overlay applied. The overlay also
  # applies to buildPackages (the x86_64 tools that compile the runtimes), so the
  # toolchain below and the runtime-builder are the *same* fork LLVM derivation —
  # it compiles once, no host/cross double-build.
  crossPkgs = import nixpkgs {
    localSystem = {inherit system;};
    crossSystem = {
      config = "wasm32-unknown-wasi";
      useLLVM = true;
    };
    overlays = [wasixOverlay];
    config.allowUnsupportedSystem = true;
  };

  # Shipped wasix toolchain = the cross's build-platform LLVM (x86_64 clang/lld
  # from the fork, multi-target so it cross-compiles to wasm).
  llvm = crossPkgs.buildPackages.llvmPackages_21;

  # libc still builds with a stock clang (the libc is independent of the LLVM
  # *source* — the wasix patches don't touch musl — so this matches upstream and
  # avoids depending on the slow toolchain build).
  libc = pkgs.callPackage ./libc.nix {};
in {
  inherit llvm libc crossPkgs;

  # Runtimes, from nixpkgs' cross machinery (deviations via wasixLlvmOverlay).
  inherit (crossPkgs.llvmPackages_21) compiler-rt libcxx libcxxabi libunwind;
}
