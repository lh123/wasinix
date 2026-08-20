{
  helpers,
  prev,
  ...
}:
helpers.wasmRename {wasmName = "patch";} (
  helpers.libTweaks {
    passthru.wasix.shipped = true;
  }
  prev.patch
)
