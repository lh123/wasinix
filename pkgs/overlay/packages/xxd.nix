{
  prev,
  helpers,
  ...
}:
helpers.wasmRename {wasmName = "xxd";} (
  helpers.libTweaks {
    passthru.wasix.shipped = true;
    postPatch = ''
      substituteInPlace Makefile \
        --replace-fail '-fPIC ' "" \
        --replace-fail ' -fno-plt -Wl,-z,now' ""
    '';
  }
  prev.xxd
)
