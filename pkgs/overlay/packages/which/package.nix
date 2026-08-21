{
  prev,
  helpers,
  ...
}:
helpers.wasmRename {wasmName = "which";} (
  helpers.libTweaks {
    patches = [./patches/webc-commands-are-executable.patch];
    passthru.wasix.shipped = true;
  }
  prev.which
)
