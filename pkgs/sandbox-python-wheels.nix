# Python wheels bundled into the investigation sandbox. Only user-facing
# capabilities are listed here; requiredPythonModules supplies their runtime
# dependency closure, and every member's dist output contributes its wheel.
{
  pkgs,
  lib,
  python3,
  pythonWheels,
}: let
  rootImports = {
    chardet = "chardet";
    defusedxml = "defusedxml";
    dill = "dill";
    lxml = "lxml";
    odfpy = "odf";
    openpyxl = "openpyxl";
    pandas = "pandas";
    puremagic = "puremagic";
    pypdf = "pypdf";
    python-docx = "docx";
    pyxlsb = "pyxlsb";
    xlrd = "xlrd";
  };
  roots = lib.attrNames rootImports;
  imports = lib.attrValues rootImports;
  rootPackages = map (name: pythonWheels.${name}) roots;
  runtimePackages = lib.unique (
    rootPackages ++ python3.pkgs.requiredPythonModules rootPackages
  );
  wheelPackages = lib.filter (package: package ? dist) runtimePackages;
  wheelDists = lib.unique (map (package: package.dist) wheelPackages);
in
  pkgs.runCommand "sandbox-python-wheels-${python3.pythonVersion}" {
    passthru = {inherit imports roots;};
  } ''
    mkdir -p "$out"
    for dist in ${lib.escapeShellArgs (map toString wheelDists)}; do
      while IFS= read -r wheel; do
        cp "$wheel" "$out/"
      done < <(find "$dist" -type f -name '*.whl')
    done
    test -n "$(find "$out" -type f -name '*.whl' -print -quit)"
  ''
