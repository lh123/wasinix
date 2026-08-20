{
  helpers,
  prev,
  ...
}:
helpers.libTweaks {
  passthru.wasix.shipped = true;
  passthru.wasmer.entrypoint = "diff";
  passthru.wasmer.commands = [
    {
      name = "cmp";
      module = "cmp";
      wasm = "cmp.wasm";
      output = "cmp.wasm";
    }
    {
      name = "diff";
      module = "diff";
      wasm = "diff.wasm";
      output = "diff.wasm";
    }
    {
      name = "diff3";
      module = "diff3";
      wasm = "diff3.wasm";
      output = "diff3.wasm";
    }
    {
      name = "sdiff";
      module = "sdiff";
      wasm = "sdiff.wasm";
      output = "sdiff.wasm";
    }
  ];
  postInstall = ''
    for prog in cmp diff diff3 sdiff; do
      if [ -f "$out/bin/$prog" ]; then
        mv "$out/bin/$prog" "$out/bin/$prog.wasm"
      fi
    done
  '';
}
prev.diffutils
