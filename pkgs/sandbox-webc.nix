{
  lib,
  pkgs,
  wasmer,
  components,
  wheels,
  pythonVersion,
}: let
  componentArgs = lib.concatMap (
    name: [
      "--component"
      "${name}=${components.${name}}"
    ]
  ) (lib.attrNames components);
  importArgs = lib.concatMap (name: ["--python-import" name]) wheels.imports;
in
  pkgs.runCommand "sandbox-webc-python${lib.replaceStrings ["."] [""] pythonVersion}" {
    passthru = {
      inherit components pythonVersion wheels;
      componentNames = lib.attrNames components;
    };
  } ''
    mkdir -p "$out"
    ${pkgs.python3}/bin/python ${./sandbox-webc.py} \
      --wasmer ${wasmer}/bin/wasmer \
      --wheels ${wheels} \
      --python-version ${lib.escapeShellArg pythonVersion} \
      --output "$out/sandbox.webc" \
      ${lib.escapeShellArgs importArgs} \
      ${lib.escapeShellArgs componentArgs}
    test "$(${pkgs.findutils}/bin/find \
      "$out" -mindepth 1 -maxdepth 1 -type f -printf '%f\n')" = sandbox.webc
  ''
