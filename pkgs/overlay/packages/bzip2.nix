{
  helpers,
  prev,
  ...
}:
helpers.wasmRename {wasmName = "bzip2";} (
  helpers.libTweaks {
    passthru.wasix.shipped = true;
    passthru.wasmer.commands = [
      {name = "bzip2";}
      {
        name = "bunzip2";
        module = "bzip2";
        wasm = "bzip2.wasm";
        output = "bunzip2.wasm";
        mainArgs = ["-d"];
      }
      {
        name = "bzcat";
        module = "bzip2";
        wasm = "bzip2.wasm";
        output = "bzcat.wasm";
        mainArgs = ["-d" "-c"];
      }
    ];
  }
  prev.bzip2
)
