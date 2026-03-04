{ lib, pkgs, nanoWasmer, grepWasmer, sedWasmer, findWasmer, gzipWasmer, tarWasmer, ncursesWasmer, crabsayWasmer, phpixPhp83Wasmer, cliPlatformWasmer }:
let
  packages = {
    nano = nanoWasmer;
    grep = grepWasmer;
    sed = sedWasmer;
    find = findWasmer;
    gzip = gzipWasmer;
    tar = tarWasmer;
    ncurses = ncursesWasmer;
    crabsay = crabsayWasmer;
    phpixPhp83 = phpixPhp83Wasmer;
    phpnixPhp83 = phpixPhp83Wasmer;
    cliPlatform = cliPlatformWasmer;
  };
  allWasmerPackages = lib.removeAttrs packages [ "phpixPhp83" "phpnixPhp83" ];

  allWasmer = pkgs.runCommand "wasix-all-wasmer" { } ''
    set -euo pipefail
    mkdir -p "$out/pkg"
    ${lib.concatMapStringsSep "\n" (attrName: ''
      if [ -d "${allWasmerPackages.${attrName}}/pkg" ]; then
        # Do not preserve top-level directory permissions from Nix store paths.
        ${pkgs.coreutils}/bin/cp -R --no-preserve=mode,ownership "${allWasmerPackages.${attrName}}/pkg/." "$out/pkg/"
      fi
    '') (builtins.attrNames allWasmerPackages)}
  '';
in
{
  inherit packages allWasmer;
}
