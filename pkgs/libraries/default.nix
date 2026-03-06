{
  nixpkgs,
  pkgs,
  pkgsCross,
  toolchain,
  includePhp ? true,
}:
let
  phpLibraries =
    if includePhp then
      import ./php {
        inherit pkgs toolchain;
      }
    else
      { };
in
{
  ncurses = pkgsCross.callPackage ./ncurses {
    inherit nixpkgs toolchain;
  };
} // phpLibraries
