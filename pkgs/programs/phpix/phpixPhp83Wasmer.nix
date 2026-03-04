{ makeWasmerPackage, phpixPhp83 }:
makeWasmerPackage {
  package = phpixPhp83;
  name = "phpixPhp83";
  license = "MIT";
  entrypoint = "phpix";
  commands = [
    {
      name = "phpix";
      module = "phpix";
      wasm = "phpix.wasm";
      output = "phpix.wasm";
      atom = "phpix";
    }
    {
      name = "php";
      module = "phpix";
      wasm = "phpix.wasm";
      output = "phpix.wasm";
      atom = "phpix";
    }
  ];
}
