# WIP scaffold for the redesigned wasix toolchain, built up in parallel with the
# existing pkgs/toolchain so we can try foundations in isolation. Currently just
# the two foundations: LLVM (from source) and libc (from source). No sysroot
# assembly, no wasixcc, no cross-platform wiring yet.
{pkgs}: {
  # Full wasix llvmPackages set (from-source fork); take .clang / .lld / .llvm.
  llvm = pkgs.callPackage ./llvm.nix {};
  libc = pkgs.callPackage ./libc.nix {};
}
