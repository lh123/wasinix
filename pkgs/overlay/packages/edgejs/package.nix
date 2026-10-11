# Edge.js for wasix (wasmerPackages.edgejs): a Node-compatible JS runtime whose
# QuickJS N-API provider is compiled into the guest, so no host engine is needed.
# Upstream drives its own wasixcc checkout; this build uses the repo stdenv and
# libc like every other package, so the guest matches the rest of the sandbox.
{
  final,
  ...
}: let
  lib = final.lib;
  inherit (final) fetchFromGitHub fetchurl;

  src = fetchFromGitHub {
    owner = "wasmerio";
    repo = "edgejs";
    rev = "18b0ce9ef6484feb796445567787a113a682a9d5";
    hash = "sha256-CLP175qtCEepESHiMUuBJZs749/RjjJLrdRJhHSf4y4=";
  };
  napi = fetchFromGitHub {
    owner = "wasmerio";
    repo = "napi";
    rev = "a65e9cb861ac31feb01438d1e498c138f18faee8";
    hash = "sha256-Zd2GlFEnvhhtvw+2R3gIw/JmiT/Qahcwl2hhT8M1mU4=";
  };
  quickjs = fetchFromGitHub {
    owner = "wasmerio";
    repo = "quickjs";
    rev = "89fb17a82ba1d38f605e01558c3928aacc4ffd54";
    hash = "sha256-02m/FMSgAispG/ny3IR3lTNVUdedAn1hikdXihcB1HY=";
  };
  libuvWasix = fetchFromGitHub {
    owner = "wasix-org";
    repo = "libuv";
    rev = "6fe6259894375cef3a7289d7dcc0a35e539191b3";
    hash = "sha256-hUTUxep8XJu3DGF8do+/fUNnovao6bS+XgZX5CpmxEI=";
  };
  opensslWasix = fetchFromGitHub {
    owner = "wasix-org";
    repo = "openssl";
    rev = "a8632cb81bc5a62f77f6286019ac922d1cd8e270";
    hash = "sha256-EbK3R4ZkB7UhahxbdvyXMNCLQMoVIlZpPAqykP0H3Fs=";
  };
  sslCerts = fetchFromGitHub {
    owner = "wasix-org";
    repo = "ssl-certs";
    rev = "9cdb2c2f753ca1094137ea4156f7ce5678aabd4b";
    hash = "sha256-c+qnHuJ2ZnsnHFVnxqWEn8rEYeaqPQ0F2O9hC+msLC8=";
  };
  # pnpm 10.34.5, the JS CLI the npm/pnpm commands run. The hash is upstream's
  # npm dist.integrity, copied from quickjs-wasm/stage-pnpm.sh.
  pnpmArchive = fetchurl {
    url = "https://registry.npmjs.org/pnpm/-/pnpm-10.34.5.tgz";
    hash = "sha512-pO4F8vc2WCVb1qiYWcBlpFwopX2u+uLIk6Fo7itzFow3uR6D5X6mdlStA/AwMXRkMOi84442LgQmBfuKvIAZLg==";
  };
  # The QuickJS wasm provider links only the *headers* of the Wasmer C API, but
  # cmake fetches the host asset at configure time, which the build sandbox
  # cannot do; fetch it here and point the build at the extracted tree.
  wasmerCapi = final.buildPackages.runCommand "wasmer-c-api-7.1.0" {} ''
    mkdir -p "$out"
    tar -xzf ${fetchurl {
      url = "https://github.com/wasmerio/wasmer/releases/download/v7.1.0/wasmer-linux-amd64.tar.gz";
      hash = "sha256-YaatD5cu4K+7eQerkPESDhXS4hnsHOCJmfKGTguMNA8=";
    }} -C "$out"
  '';

  # upstream's wasix-toolchain.cmake injects these; the toolchain file below
  # leaves the compilers and sysroot to the stdenv.
  compatFlags = "-mno-wide-arithmetic -D_GNU_SOURCE -D_WASI_EMULATED_MMAN -D_WASI_EMULATED_SIGNAL -D_WASI_EMULATED_PROCESS_CLOCKS -include ${src}/wasix/src/wasix_compat.h -isystem ${src}/wasix/cmake/wasix-compat-include";

  # CMake must see the target named WASI: nixpkgs calls the platform WasiP1, and
  # both libuv (its WASI source set) and Edge.js select the wasix paths by that
  # name. The compilers and sysroot come from the stdenv, so this file carries
  # only the cross facts (compiler-rt and ddtrace do the same).
  toolchainFile = final.buildPackages.writeText "edgejs-wasi-toolchain.cmake" ''
    set(CMAKE_SYSTEM_NAME WASI)
    set(CMAKE_SYSTEM_VERSION 1)
    set(CMAKE_SYSTEM_PROCESSOR wasm32)
    set(CMAKE_EXECUTABLE_SUFFIX ".wasm")
    set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
    set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
    # find_package(Python3) needs the build-host interpreter
    set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
  '';

  # The webc's fs volumes, kept as separate derivations so the package does not
  # mount its own output.
  pnpmTree = final.runCommand "edgejs-pnpm-10.34.5" {} ''
    mkdir -p "$out"
    tar -xOf ${pnpmArchive} package/dist/pnpm.cjs > "$out/pnpm.cjs"
    tar -xOf ${pnpmArchive} package/dist/worker.js > "$out/worker.bundle.js"
    tar -xOf ${pnpmArchive} package/LICENSE > "$out/LICENSE"
    tar -xOf ${pnpmArchive} package/package.json > "$out/package.json"
    cp ${src}/quickjs-wasm/pnpm/edge-pnpm.cjs "$out/edge-pnpm.cjs"
    cp ${src}/quickjs-wasm/pnpm/wasix-fs.cjs "$out/wasix-fs.cjs"
    # pnpm loads its tarball worker from "./worker.js" next to pnpm.cjs, so the
    # bundle is staged under that path; the shim installs the fs adapter in the
    # worker thread before the bundle runs.
    cat > "$out/worker.js" <<'EOF'
'use strict'

require('./wasix-fs.cjs')

require('./worker.bundle.js')
EOF
  '';
  # A command's main-args and env are applied when the runtime starts it as the
  # run entrypoint; a shell that spawns /bin/pnpm gets the bare module. These
  # wrappers carry the annotations and win on PATH, which lists /usr/local/bin
  # first.
  pnpmWrappers = final.runCommand "edgejs-pnpm-wrappers" {} ''
    mkdir -p "$out/bin"
    for name in pnpm npm; do
      cat > "$out/bin/$name" <<'EOF'
#!/bin/bash
export HOME=/tmp
export npm_config_network_concurrency=4
export npm_config_node_linker=hoisted
export npm_config_package_import_method=copy
export npm_config_store_dir=/tmp/.pnpm-store
export npm_config_update_notifier=false
exec /bin/node /pnpm/edge-pnpm.cjs "$@"
EOF
      chmod +x "$out/bin/$name"
    done
  '';
  etcTree = final.runCommand "edgejs-etc" {} ''
    cp -r ${src}/quickjs-wasm/etc "$out"
  '';
  sslTree = final.runCommand "edgejs-ssl-certs" {} ''
    cp -r ${sslCerts} "$out"
  '';
in
  final.stdenv.mkDerivation (finalAttrs: {
    pname = "edgejs";
    version = "0.2.5-g18b0ce9";
    inherit src;

    nativeBuildInputs = [
      # build-platform tools: the cross set's cmake/ninja are wasm builds whose
      # recipes assume a libc the wasix stdenv does not have.
      final.buildPackages.cmake
      final.buildPackages.ninja
      # openssl's Configure/make are perl scripts
      final.buildPackages.perl
      final.buildPackages.pkg-config
      final.buildPackages.python3
    ];

    # The tarball carries no submodules; place the ones the wasix build uses.
    # wasmer-examples (ssh remote) and test are skipped: the latter only feeds
    # the real-npm fallback, which this package leaves out.
    postPatch = ''
      # the archive carries the submodule paths as empty directories, so clear
      # each before copying or the tree nests one level deeper.
      rm -rf napi deps/libuv-wasix deps/openssl-wasix
      cp -a ${napi} napi
      cp -a ${libuvWasix} deps/libuv-wasix
      cp -a ${opensslWasix} deps/openssl-wasix
      # the store copies are read-only; make them writable before editing
      chmod -R u+w napi deps/libuv-wasix deps/openssl-wasix
      # copied in after patchPhase, so their /usr/bin/env shebangs are still
      # unresolved when perl scripts (Configure, make helpers) run
      patchShebangs --build deps/openssl-wasix
      rm -rf napi/quickjs/deps/quickjs
      cp -a ${quickjs} napi/quickjs/deps/quickjs
      chmod -R u+w napi deps/libuv-wasix deps/openssl-wasix
    '';

    # upstream builds the static OpenSSL before cmake; keep that order.
    preConfigure = ''
      ( cd deps/openssl-wasix
        ./Configure linux-generic32 -static no-shared no-pic no-asm no-dso no-tests no-apps no-afalgeng \
          -DUSE_TIMEGM -DOPENSSL_NO_SECURE_MEMORY -DOPENSSL_NO_DGRAM -DOPENSSL_THREADS
        make build_generated
        make -j"$NIX_BUILD_CORES" libcrypto.a libssl.a
      )
      # the cmake setup hook word-splits cmakeFlags, so a value carrying spaces
      # cannot go through them; inject the compat flags for the cmake compiles
      # only, after openssl (which does not want the shim header) is built.
      export NIX_CFLAGS_COMPILE="''${NIX_CFLAGS_COMPILE-} ${compatFlags}"
    '';

    cmakeFlags = [
      (lib.cmakeFeature "CMAKE_TOOLCHAIN_FILE" "${toolchainFile}")
      "-DEDGE_NAPI_PROVIDER=quickjs"
      "-DEDGE_BUILD_CLI=ON"
      "-DBUILD_TESTING=OFF"
      "-DEDGE_QUICKJS_WASMER_DIST_ROOT=${wasmerCapi}"
    ];

    installPhase = ''
      runHook preInstall
      # the cmake hook leaves the phases in the build directory, and upstream
      # accepts either the bare name or cmake's .wasm suffix.
      bin=edge
      [ -f "$bin" ] || bin=edge.wasm
      install -Dm755 "$bin" "$out/bin/edge.wasm"
      runHook postInstall
    '';

    passthru = {
      wasix.shipped = true;
      wasmer = {
        name = "edgejs";
        entrypoint = "edge";
        # upstream's version is already valid semver (0.2.5-g<rev>); toSemver
        # would fold the four git-suffix digits and collide across revs.
        version = v: v;
        fs = {
          "/etc" = etcTree;
          "/pnpm" = pnpmTree;
          "/usr/local" = pnpmWrappers;
          "/usr/local/ssl" = sslTree;
        };
        # One module, four commands; npm runs the same pnpm CLI upstream ships.
        commands = [
          {
            name = "edge";
            module = "edge";
            wasm = "edge.wasm";
            output = "edge.wasm";
          }
          {
            name = "node";
            module = "edge";
            wasm = "edge.wasm";
            output = "edge.wasm";
          }
          {
            name = "pnpm";
            module = "edge";
            wasm = "edge.wasm";
            output = "edge.wasm";
            mainArgs = ["/pnpm/edge-pnpm.cjs"];
            env = {
              HOME = "/tmp";
              npm_config_network_concurrency = "4";
              npm_config_node_linker = "hoisted";
              npm_config_package_import_method = "copy";
              npm_config_store_dir = "/tmp/.pnpm-store";
              npm_config_update_notifier = "false";
            };
          }
          {
            name = "npm";
            module = "edge";
            wasm = "edge.wasm";
            output = "edge.wasm";
            mainArgs = ["/pnpm/edge-pnpm.cjs"];
            env = {
              HOME = "/tmp";
              npm_config_network_concurrency = "4";
              npm_config_node_linker = "hoisted";
              npm_config_package_import_method = "copy";
              npm_config_store_dir = "/tmp/.pnpm-store";
              npm_config_update_notifier = "false";
            };
          }
        ];
      };
    };

    meta = {
      description = "Node-compatible JavaScript runtime with an embedded QuickJS engine";
      homepage = "https://github.com/wasmerio/edgejs";
      license = lib.licenses.mit;
      mainProgram = "edge";
    };
  })
