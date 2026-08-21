{
  prev,
  helpers,
  ...
}: let
  oldProvider = prev.xxd.provider;
  provider = helpers.libTweaks {
    postPatch = ''
      substituteInPlace Makefile \
        --replace-fail '-fPIC ' "" \
        --replace-fail ' -fno-plt -Wl,-z,now' ""
    '';
  } oldProvider;
  xxd = prev.xxd.overrideAttrs (old: {
    buildCommand = ''
      mkdir -p "$out/bin"
      cp --dereference ${provider}/bin/xxd "$out/bin/xxd.wasm"
    '';
    passthru = (old.passthru or {}) // {inherit provider;};
  });
in
  helpers.libTweaks {
    passthru.wasix.shipped = true;
  }
  xxd
