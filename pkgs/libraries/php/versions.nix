{ lib, fetchFromGitHub }:
let
  commonConfigureFlags = [
    "--enable-fd-setsize=8192"
    "--enable-static"
    "--disable-shared"
    "--host=wasm32-wasi"
    "--target=wasm32-wasi"
    "--disable-opcache-jit"
    "--disable-huge-code-pages"
    "--disable-rpath"
    "--disable-cgi"
    "--with-zlib"
    "--with-openssl"
    "--enable-mbstring"
    "--enable-mbregex"
    "--disable-zend-signals"
    "--with-valgrind=no"
    "--with-pcre-jit=no"
    "--with-iconv"
    "--disable-phpdbg"
    "--enable-bcmath"
    "--enable-gd"
    "--enable-exif"
    "--with-jpeg"
    "--with-freetype"
    "--with-webp"
    "--enable-fiber-asm"
    "--with-curl"
    "--with-mysqli=mysqlnd"
    "--with-pdo-mysql=mysqlnd"
    "--with-zip"
    "--with-sodium"
    "--enable-intl"
    "--with-pdo-sqlite"
    "--enable-ftp"
    "--enable-igbinary"
    "--with-imagick"
    "--program-suffix=.wasm"
    "--enable-zts"
    "--enable-embed=static"
  ];

  phpWasixDeps = fetchFromGitHub {
    owner = "wasix-org";
    repo = "php-wasix-deps";
    rev = "e1d0878e590c6f10e31e4c14294c617bac1f775c";
    hash = "sha256-1awrT/rKJHHME+KILCs/TW/1RtfjWTqgkaHIz2FSt9o=";
  };

  commonBundledExtensions = {
    igbinary = {
      src = fetchFromGitHub {
        owner = "igbinary";
        repo = "igbinary";
        rev = "8326f6a69ebb30dd6258dd536eb0914454fbf146";
        hash = "sha256-uBnM+zqwnaXzqt7XO6g87XEW3zp0clhuMgihlCV8apE=";
      };
    };

    imagick = {
      src = fetchFromGitHub {
        owner = "Imagick";
        repo = "imagick";
        rev = "52ec37ff633de0e5cca159a6437b8c340afe7831";
        hash = "sha256-DcZ6a0ANDj8aGsqd/+cSFngeP+tTfKOwVqPDi4hjVqE=";
      };
      patches = [
        ./patches/extensions/imagick-bundled-build.patch
      ];
    };
  };

  mkPhpZts = {
    series,
    upstreamVersion,
    srcRev,
    srcHash,
    patches,
    extraConfigureFlags ? [ ],
    bundledExtensions ? commonBundledExtensions,
  }:
  rec {
    pname = "php${series}-zts";
    version = "${upstreamVersion}-wasix";

    src = fetchFromGitHub {
      owner = "php";
      repo = "php-src";
      rev = srcRev;
      hash = srcHash;
    };

    inherit phpWasixDeps bundledExtensions patches;

    configureFlags = commonConfigureFlags ++ extraConfigureFlags ++ [
      "--with-pgsql=${phpWasixDeps}/pgsql-eh"
      "--with-pdo-pgsql=${phpWasixDeps}/pgsql-eh"
    ];

    meta = {
      description = "Static PHP ${upstreamVersion} WASIX ZTS libphp build";
      homepage = "https://github.com/php/php-src";
      license = lib.licenses.php301;
      platforms = lib.platforms.linux;
    };
  };
in
{
  php83 = mkPhpZts {
    series = "83";
    upstreamVersion = "8.3.21";
    srcRev = "2d2a21057fe357941652a2d1b5f296f527a0bee0";
    srcHash = "sha256-pLH+P1nBPXCmdy8OpcxhuDV4+ClZuv5XA5WujdorUCc=";
    extraConfigureFlags = [
      "--enable-opcache"
    ];
    patches = [
      ./patches/common/0001-wasix-core-support.patch
      ./patches/common/0002-opcache-static-embed.patch
      ./patches/common/0003-cli-server-instaboot.patch
    ];
  };

  php85 = mkPhpZts {
    series = "85";
    upstreamVersion = "8.5.3";
    srcRev = "f665c20219d0861fcbdd1f663fc4ac061f245a3c";
    srcHash = "sha256-/chajkaMVtXTFdgAKEHaQA7FjLsYMyxLDYb+JXDLS4c=";
    patches = [
      ./patches/php85/0001-wasix-core-support.patch
      ./patches/php85/0002-opcache-static-embed.patch
    ];
  };
}
