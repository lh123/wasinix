{ lib, pkgs, nanoWasmer, grepWasmer, sedWasmer, findWasmer, gzipWasmer, tarWasmer, lessWasmer, ncursesWasmer, crabsayWasmer, phpixPhp83Wasmer, phpixPhp85Wasmer, cliPlatformWasmer }:
let
  packages = {
    nano = nanoWasmer;
    grep = grepWasmer;
    sed = sedWasmer;
    find = findWasmer;
    gzip = gzipWasmer;
    tar = tarWasmer;
    less = lessWasmer;
    ncurses = ncursesWasmer;
    crabsay = crabsayWasmer;
    phpixPhp83 = phpixPhp83Wasmer;
    phpnixPhp83 = phpixPhp83Wasmer;
    phpixPhp85 = phpixPhp85Wasmer;
    phpnixPhp85 = phpixPhp85Wasmer;
    cliPlatform = cliPlatformWasmer;
  };
  allWasmerPackages = lib.removeAttrs packages [ "phpixPhp83" "phpnixPhp83" "phpixPhp85" "phpnixPhp85" ];

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
