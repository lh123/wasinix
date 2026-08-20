{
  helpers,
  prev,
  ...
}:
helpers.wasmRename {wasmName = "xz";} (
  helpers.libTweaks {
    passthru.wasix.shipped = true;
    passthru.wasmer.commands = [
      {name = "xz";}
      {
        name = "unxz";
        module = "xz";
        wasm = "xz.wasm";
        output = "unxz.wasm";
        mainArgs = ["-d"];
      }
      {
        name = "xzcat";
        module = "xz";
        wasm = "xz.wasm";
        output = "xzcat.wasm";
        mainArgs = ["-d" "-c"];
      }
      {
        name = "lzma";
        module = "xz";
        wasm = "xz.wasm";
        output = "lzma.wasm";
      }
      {
        name = "unlzma";
        module = "xz";
        wasm = "xz.wasm";
        output = "unlzma.wasm";
        mainArgs = ["-d"];
      }
      {
        name = "lzcat";
        module = "xz";
        wasm = "xz.wasm";
        output = "lzcat.wasm";
        mainArgs = ["-d" "-c"];
      }
    ];
  }
  prev.xz
)
