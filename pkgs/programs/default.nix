{ nixpkgs, pkgs, pkgsCross, toolchain, libs }:
rec {
  nano = pkgsCross.callPackage ./nano/nano.nix {
    inherit nixpkgs toolchain;
    ncurses = libs.ncursesLib;
  };
  grep = pkgsCross.callPackage ./grep/grep.nix {
    inherit toolchain;
  };
  sed = pkgsCross.callPackage ./sed/sed.nix {
    inherit toolchain;
  };
  find = pkgsCross.callPackage ./find/find.nix {
    inherit toolchain;
  };
  gzip = pkgsCross.callPackage ./gzip/gzip.nix {
    inherit toolchain;
  };
  tar = pkgsCross.callPackage ./tar/tar.nix {
    inherit toolchain;
  };
  less = pkgsCross.callPackage ./less/less.nix {
    inherit toolchain;
    ncurses = libs.ncursesLib;
  };
  ncurses = pkgsCross.callPackage ./ncurses/ncurses.nix {
    inherit nixpkgs toolchain;
  };

  crabsay = pkgs.callPackage ./crabsay/crabsay.nix {
    cargoWasix = toolchain.cargoWasix;
  };

  phpPhpix83 = pkgs.callPackage ./php/phpPhpix83.nix {
    inherit toolchain;
  };

  phpixPhp83 = pkgs.callPackage ./phpix/phpixPhp83.nix {
    cargoWasix = toolchain.cargoWasix;
    inherit toolchain phpPhpix83;
  };
}
