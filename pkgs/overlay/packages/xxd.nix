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
    buildCommand =
      builtins.replaceStrings
      ["${oldProvider}"]
      ["${provider}"]
      old.buildCommand
      + ''
        cp --dereference "$out/bin/xxd" "$out/bin/xxd.wasm"
        rm "$out/bin/xxd"
      '';
    passthru = (old.passthru or {}) // {inherit provider;};
  });
in
  helpers.libTweaks {
    passthru.wasix.shipped = true;
  }
  xxd
