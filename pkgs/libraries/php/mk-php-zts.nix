{
  lib,
  stdenvNoCC,
  autoconf,
  bison,
  re2c,
  pkg-config,
  gnumake,
  perl,
  python3,
  coreutils,
  patch,
  toolchain,
}:
{
  pname,
  version,
  src,
  phpWasixDeps,
  patches ? [ ],
  bundledExtensions ? { },
  configureFlags,
  meta ? { },
  passthru ? { },
}:
stdenvNoCC.mkDerivation {
  inherit pname version src patches;

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
    patch
  ];

  enableParallelBuilding = true;

  postPatch =
    let
      bundledExtensionNames = builtins.attrNames bundledExtensions;
      copyBundledExtensions = lib.concatMapStringsSep "\n" (name:
        let
          extension = bundledExtensions.${name};
          extensionPatches = extension.patches or [ ];
          applyExtensionPatches = lib.concatMapStringsSep "\n" (patchFile:
            "patch -p1 < ${lib.escapeShellArg "${patchFile}"}"
          ) extensionPatches;
        in
        ''
          rm -rf "ext/${name}"
          mkdir -p "ext/${name}"
          cp -R --no-preserve=mode,ownership ${extension.src}/. "ext/${name}"
          chmod -R u+w "ext/${name}"
          ${applyExtensionPatches}
        ''
      ) bundledExtensionNames;
      patchTargets = lib.concatStringsSep " " ([ "buildconf" "build" "scripts" ] ++ map (name: "ext/${name}") bundledExtensionNames);
    in
    ''
      ${copyBundledExtensions}
      patchShebangs ${patchTargets}
    '';

  configurePhase =
    let
      configureEnv = {
        PHP_WASIX_DEPS = toString phpWasixDeps;
        CURL_CFLAGS = "-I${phpWasixDeps}/include/curl";
        CURL_LIBS = "-lcurl -lcrypto -lssl";
        ZLIB_CFLAGS = "-I${phpWasixDeps}/include/zlib";
        ZLIB_LIBS = "-lz";
        LIBXML_CFLAGS = "-I${phpWasixDeps}/include/libxml2";
        LIBXML_LIBS = "-lxml2 -llzma";
        SQLITE_CFLAGS = "-I${phpWasixDeps}/include/sqlite";
        SQLITE_LIBS = "-lsqlite3";
        OPENSSL_CFLAGS = "-I${phpWasixDeps}/include/openssl";
        OPENSSL_LIBS = "-lssl -lcrypto";
        ICONV_CFLAGS = "-I${phpWasixDeps}/include/iconv";
        ICONV_LIBS = "-liconv -lcharset -licrt";
        ICU_CFLAGS = "-I${phpWasixDeps}/include/icu -std=c11 -DU_DISABLE_VERSION_SUFFIX -DU_DISABLE_RENAMING";
        ICU_CXXFLAGS = "-I${phpWasixDeps}/include/icu -std=c++17 -DU_DISABLE_VERSION_SUFFIX -DU_DISABLE_RENAMING";
        ICU_LIBS = "-licudata -licui18n -licuio -licutu -licuuc";
        PNG_CFLAGS = "-I${phpWasixDeps}/include/png";
        PNG_LIBS = "-lpng";
        JPEG_CFLAGS = "-I${phpWasixDeps}/include/jpeg";
        JPEG_LIBS = "-ljpeg";
        FREETYPE2_CFLAGS = "-I${phpWasixDeps}/include/freetype";
        FREETYPE2_LIBS = "-lfreetype";
        WEBP_CFLAGS = "-I${phpWasixDeps}/include/webp";
        WEBP_LIBS = "-lwebp -lsharpyuv";
        LIBZIP_CFLAGS = "-I${phpWasixDeps}/include/libzip";
        LIBZIP_LIBS = "-lzip";
        LIBSODIUM_CFLAGS = "-I${phpWasixDeps}/include/libsodium";
        LIBSODIUM_LIBS = "-lsodium";
        ONIG_CFLAGS = "-I${phpWasixDeps}/include/oniguruma";
        ONIG_LIBS = "-lonig";
        IM_IMAGEMAGICK_CFLAGS = "-I${phpWasixDeps}/include/ImageMagick -DIM_MAGICKWAND_HEADER_STYLE_SEVEN -DMAGICKCORE_QUANTUM_DEPTH=16 -DMAGICKCORE_HDRI_ENABLE=1 -DMAGICKCORE_CHANNEL_MASK_DEPTH=32";
        IM_IMAGEMAGICK_LIBS = "-lMagickCore-7.Q16HDRI -lMagickWand-7.Q16HDRI -ltiff";
        PHP_BUILD_SYSTEM = "clang(WASIX+WasmEH)";
        PHP_EXTRA_INCLUDES = "";
        PHP_IPV6 = "yes";
        RANLIB = "wasixranlib";
        AR = "wasixar";
        NM = "wasixnm";
        CC = "wasixcc";
        CXX = "wasixcc++";
        CFLAGS = "-g -flto -O2";
        CXXFLAGS = "-g -flto -O2";
        LIBS = "-L${phpWasixDeps}/lib-eh --no-wasm-opt";
        WASIXCC_INCLUDE_CPP_SYMBOLS = "yes";
        WASIXCC_WASM_EXCEPTIONS = "legacy";
        PROG_SENDMAIL = "/usr/bin/sendmail";
      };
      exportConfigureEnv = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value:
        "export ${name}=${lib.escapeShellArg value}"
      ) configureEnv);
    in
    ''
      runHook preConfigure

      ${toolchain.commonPreConfigure}
      ${exportConfigureEnv}

      installPrefix="$PWD/install"
      ./buildconf --force
      ./configure ${lib.escapeShellArgs configureFlags} --prefix="$installPrefix"

      runHook postConfigure
    '';

  buildPhase = ''
    runHook preBuild
    make -j''${NIX_BUILD_CORES:-1} install-headers install-sapi
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -a install/. "$out/"
    runHook postInstall
  '';

  passthru = passthru // {
    inherit phpWasixDeps bundledExtensions;
  };

  meta = {
    description = "Static WASIX libphp build";
    homepage = "https://github.com/php/php-src";
  } // meta;
}
