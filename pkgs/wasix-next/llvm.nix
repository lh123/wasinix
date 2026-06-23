# Foundation (new design, WIP): build the wasix LLVM toolchain FROM SOURCE by
# pointing nixpkgs' llvmPackages_21 at the wasix-org/llvm-project fork (which
# already carries the wasix patches). Replaces the prebuilt-binary fetchurl in
# pkgs/toolchain/wasix-llvm.nix.
#
# Uses LLVM's bespoke override interface (same shape as rocmPackages' LLVM):
# pass `version` explicitly so nixpkgs selects the right patch set, and
# `officialRelease = {}` + `monorepoSrc`/`src` to override the source entirely
# (rather than `.override { monorepoSrc }` alone, which would keep nixpkgs'
# 21.1.8 version/patches against this 21.1.2-based fork).
#
# Returns the full llvmPackages set; consumers take .clang / .lld / .llvm etc.
{
  lib,
  llvmPackages_21,
  fetchFromGitHub,
}: let
  monorepoSrc = fetchFromGitHub {
    owner = "wasix-org";
    repo = "llvm-project";
    rev = "63389e381615454b876e6a24afd878af6cad2b96"; # release tag 21.1.203
    hash = "sha256-IFQNaJfBTVXWYsahkCGLMbmcs6vWDEwr6xKszq7yHSM=";
  };
in
  llvmPackages_21.override (_old: {
    officialRelease = {}; # set-but-empty: source comes entirely from monorepoSrc
    version = "21.1.2"; # fork's actual LLVM base (llvm/CMakeLists.txt); selects patches
    src = monorepoSrc;
    inherit monorepoSrc;
    doCheck = false;
  })
