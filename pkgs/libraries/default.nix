{ nixpkgs, pkgs, pkgsCross, toolchain }:
let
  phpLibraries = import ./php {
    inherit pkgs toolchain;
  };
in
{
  ncursesLib = pkgsCross.callPackage ./ncurses {
    inherit nixpkgs toolchain;
  };
} // phpLibraries
