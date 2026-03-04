{
  lib,
  stdenvNoCC,
  rustPlatform,
  cargoWasix,
  gcc,
  llvmPackages,
  phpPhpix83,
  toolchain,
}:
stdenvNoCC.mkDerivation rec {
  pname = "phpix-php83";
  version = "0.1.1080321-alpha.7";

  src = ../../../vendor/phpix;

  cargoDeps = rustPlatform.importCargoLock {
    lockFile = ./phpix.Cargo.lock;
    allowBuiltinFetchGit = true;
  };

  nativeBuildInputs = [
    rustPlatform.cargoSetupHook
    cargoWasix
    toolchain.wasixcc
    toolchain.wasixLlvm
    gcc
    llvmPackages.libclang
  ];

  buildPhase = ''
    runHook preBuild

    substituteInPlace build.rs --replace-fail "WASM_EXCEPTIONS=legacy" "WASM_EXCEPTIONS=yes"

    export HOME="$PWD/.home"
    export CARGO_HOME="$HOME/.cargo"
    export RUSTUP_HOME="$HOME/.rustup"
    mkdir -p "$HOME" "$CARGO_HOME" "$RUSTUP_HOME"

    SYSROOT_PATH="$(wasixccenv -sWASM_EXCEPTIONS=yes print-sysroot)"
    export WASIX_PHP_HOME="${phpPhpix83}"
    export WASIX_PHP_EXTRA_LIB_DIR="${phpPhpix83.phpWasixDeps}/lib-eh:${phpPhpix83.phpWasixDeps}/pgsql/lib:$SYSROOT_PATH/lib/wasm32-wasi"
    export PATH="${toolchain.wasixLlvm}/bin:$SYSROOT_PATH/../../llvm/bin:$PATH"

    export LIBCLANG_PATH="${llvmPackages.libclang.lib}/lib"
    export CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER="${gcc}/bin/gcc"
    cargo-wasix wasix build --release --frozen --offline

    runHook postBuild
  '';

  prePatch = ''
    cp ${./phpix.Cargo.lock} Cargo.lock
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    cp target/wasm32-wasmer-wasi/release/phpix.wasm "$out/bin/phpix.wasm"
    runHook postInstall
  '';

  meta = {
    description = "PHPix server for WASIX built against PHP 8.3 static libphp";
    homepage = "https://github.com/wasmerio/phpix";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
