{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  autoconf,
  bison,
  re2c,
  pkg-config,
  gnumake,
  perl,
  python3,
  coreutils,
  toolchain,
}:
let
  phpWasixDeps = fetchFromGitHub {
    owner = "wasix-org";
    repo = "php-wasix-deps";
    rev = "e1d0878e590c6f10e31e4c14294c617bac1f775c";
    hash = "sha256-1awrT/rKJHHME+KILCs/TW/1RtfjWTqgkaHIz2FSt9o=";
  };
in
stdenvNoCC.mkDerivation rec {
  pname = "php-phpix-static";
  version = "8.3.21-phpix-opcache-lock-fixes";

  src = fetchFromGitHub {
    owner = "wasix-org";
    repo = "php";
    rev = "058bf6e7484a4967adc5d023fda7596eaacc18f9";
    hash = "sha256-T7euzztZf2C6NZeTbnXTrwvxXm9XF1Uo/4EGX9oIXY8=";
  };

  nativeBuildInputs = [
    toolchain.wasixcc
    autoconf
    bison
    re2c
    pkg-config
    gnumake
    perl
    python3
    coreutils
  ];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild

    ${toolchain.commonPreConfigure}
    export WASIX_PHP_DEPS="${phpWasixDeps}"
    ln -sfn "${phpWasixDeps}" ../php-wasix-deps
    patchShebangs wasix-*.sh
    substituteInPlace wasix-configure-eh.sh --replace-fail "WASIXCC_WASM_EXCEPTIONS=\"legacy\"" "WASIXCC_WASM_EXCEPTIONS=\"yes\""

    ./buildconf --force
    sh ./wasix-configure-libphp-32.sh
    sh ./wasix-build-libphp.sh

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -a install/. "$out/"
    runHook postInstall
  '';

  meta = {
    description = "Static PHP 8.3 WASIX libphp build for PHPix";
    homepage = "https://github.com/wasix-org/php";
    license = lib.licenses.php301;
    platforms = lib.platforms.linux;
  };

  passthru = {
    inherit phpWasixDeps;
  };
}
