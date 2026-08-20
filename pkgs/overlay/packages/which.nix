{
  prev,
  helpers,
  ...
}:
helpers.wasmRename {wasmName = "which";} (
  helpers.libTweaks {
    passthru.wasix.shipped = true;
  }
  prev.which
)
