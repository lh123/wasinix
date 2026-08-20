{
  prev,
  helpers,
  ...
}:
helpers.wasmRename {wasmName = "file";} (
  helpers.libTweaks {
    passthru.wasix.shipped = true;
    passthru.wasmer = {
      env.MAGIC = "/usr/share/misc/magic.mgc";
      fs."/usr/share/misc" = "${prev.file}/share/misc";
    };
  }
  prev.file
)
