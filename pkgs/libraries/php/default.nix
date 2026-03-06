{ pkgs, toolchain }:
let
  versions = import ./versions.nix {
    inherit (pkgs) lib fetchFromGitHub;
  };
  mkPhpZts = pkgs.callPackage ./mk-php-zts.nix {
    inherit toolchain;
  };
in
{
  php83ZTS = mkPhpZts versions.php83;
  php85ZTS = mkPhpZts versions.php85;
}
