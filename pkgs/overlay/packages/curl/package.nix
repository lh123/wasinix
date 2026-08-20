# Both libcurl (linked by git/imagemagick via lib/libcurl.a, unaffected by
# the bin rename) and the curl CLI, shipped as curl.wasm. openssl, zlib,
# brotli and zstd auto-thread; the other *Support flags need libs we don't
# package yet (nghttp2, c-ares, libidn2, libpsl, ...).
{
  final,
  prev,
  helpers,
  ...
}:
let
  curlRevision = "ab18c04218ff316cd67b1e928c5cee579b2f66a0";
  curlSource = final.fetchurl {
    url = "https://github.com/curl/curl/archive/${curlRevision}.tar.gz";
    hash = "sha256-GB9dqMICElKx9o+iL7N91paPHfQ6/26Y8sAnMCT1/Pg=";
  };
  curlPackage = helpers.libTweaks {
    passthru.wasix.shipped = true;
    pname = "curl";
    version = "8.4.0";
    src = curlSource;
    patches = _: [
      ./patches/curl-0001-WASIX-Add-source-changes.patch
      ./patches/curl-0002-Remove-defines-in-setup-vms.h-that-cause-undefined-s.patch
      ./patches/curl-0003-Make-sure-no-unsupported-flags-are-passed-to-send-an.patch
      ./patches/curl-0004-Fix-the-cmake-scripts-not-detecting-poll-under-WASIX.patch
      ./patches/curl-0005-Link-Brotli-common-for-static-WASIX-builds.patch
    ];
    nativeBuildInputs = [final.buildPackages.autoreconfHook];
    postPatch = _: ''
      patchShebangs scripts
    '';
    preConfigure = _: ''
      substituteInPlace ./config.guess --replace-fail /usr/bin/uname uname
      sed -e 's|/usr/bin|/no-such-path|g' -i.bak configure
    '';
    configureFlags = old: final.lib.filter (flag: flag != "--with-ca-fallback") old;
  } (prev.curlMinimal.override {
    # The static cross build does not need a target shell.
    runtimeShellPackage = null;
    brotliSupport = true;
    c-aresSupport = false;
    gssSupport = false;
    http2Support = false;
    http3Support = false;
    websocketSupport = false;
    idnSupport = false;
    ldapSupport = false;
    opensslSupport = true;
    pslSupport = false;
    rtmpSupport = false;
    rustlsSupport = false;
    scpSupport = false;
    zlibSupport = true;
    zstdSupport = true;
  });
in
helpers.wasmRename {wasmName = "curl";} curlPackage
