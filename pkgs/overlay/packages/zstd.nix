# zstd's build uses bash + grep as *host* deps (not spliced to the build
# platform), so the defaults would build a wasm bash/grep (→ pcre2) that can't
# link for WASI. Pin them to the build platform explicitly.
{
  final,
  prev,
  helpers,
  ...
}:
helpers.wasmRename {wasmName = "zstd";} (
  helpers.libTweaks {
    passthru.wasix.shipped = true;
    passthru.wasmer.commands = [
      {name = "zstd";}
      {
        name = "unzstd";
        module = "zstd";
        wasm = "zstd.wasm";
        output = "unzstd.wasm";
        mainArgs = ["-d"];
      }
      {
        name = "zstdcat";
        module = "zstd";
        wasm = "zstd.wasm";
        output = "zstdcat.wasm";
        mainArgs = ["-d" "-c"];
      }
    ];
  }
  (prev.zstd.override {
    bashNonInteractive = final.buildPackages.bashNonInteractive;
    gnugrep = final.buildPackages.gnugrep;
  })
)
