{
  prev,
  helpers,
  ...
}:
helpers.wasmRename {wasmName = "xxd";} (
  helpers.libTweaks {
    passthru.wasix.shipped = true;
  }
  prev.xxd
)
