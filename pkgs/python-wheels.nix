# The shipped Python wheels + import smoke-tests. Exposes each wheel in
# overlay/python-packages/wheels.nix as pythonWheels.<attr> (the wasm cross build) and
# .tests (an import run under wasmer), for `.#pythonWheels.<attr>` targets + checks.wheel-<attr>.
{
  pkgs,
  lib,
  # the wasix cpython at its ehpic profile (drives the wheel closure + version).
  python3,
  # the self-contained python webc; the interpreter it bundles runs the import
  # test with no host /nix/store.
  pythonWebc,
  # wasmer runtime for the smoke-tests (flake input; null -> pkgs.wasmer).
  wasmer ? null,
  mkTestGroup,
  # Which worklist entries this call builds. noarch wheels (python-version-independent: they ship
  # no python code, e.g. a redistributed binary) build once on the default python; everything else
  # builds per interpreter. See pkgs/default.nix.
  select ? (_: true),
}: let
  effWasmer =
    if wasmer != null
    then wasmer
    else pkgs.wasmer;

  wheelList = import ./overlay/python-packages/wheels.nix;
  pyImportOf = e: e.pyImport or (lib.replaceStrings ["-"] ["_"] e.attr);

  # Run a python `script` on the SELF-CONTAINED python webc with the wheel + its
  # dep closure copied into a plain (non-store) dir and NO /nix/store mounted -- as
  # `pip install --target` then a run would on a bare wasix target. A wheel that
  # reaches an unmounted store path (a ctypes .so, a spawned binary) fails here, as
  # it would under real pip. Only HOME is writable (some wheels resolve a config dir
  # at import, e.g. matplotlib.get_configdir). The script fails the check by raising;
  # the trailing marker confirms it ran through. Shared by the import smoke-test and
  # the per-package tests/ (see mkWheel).
  runPython = {
    name,
    wheel,
    script,
  }: let
    pythonPath = python3.pkgs.makePythonPath [wheel];
    marker = "PYRUN_OK ${name}";
    file = pkgs.writeText "${name}.py" ''
      ${script}
      print(${builtins.toJSON marker})
    '';
  in
    pkgs.runCommand name {
      nativeBuildInputs = [effWasmer];
    } ''
      export HOME=$TMPDIR/home
      mkdir -p "$HOME"
      webc=$(${pkgs.findutils}/bin/find ${pythonWebc} -name '*.webc' | head -1)

      site=$TMPDIR/site
      mkdir -p "$site"
      IFS=: read -ra _paths <<< ${lib.escapeShellArg pythonPath}
      for p in "''${_paths[@]}"; do
        [ -d "$p" ] && ${pkgs.rsync}/bin/rsync -a --chmod=u+w "$p"/ "$site"/
      done
      cp ${file} "$site/__pyrun__.py"

      log=$(mktemp)
      if timeout 600 wasmer run \
        --volume "$site":/site \
        --mapdir /home:"$HOME" \
        --env HOME=/home \
        --env PYTHONPATH=/site \
        "$webc" -- /site/__pyrun__.py >"$log" 2>&1 \
        && ${pkgs.gnugrep}/bin/grep -q ${lib.escapeShellArg marker} "$log"; then
        cp "$log" "$out"
      else
        echo "python test '${name}' failed (no /nix/store, pip-like):" >&2
        cat "$log" >&2
        exit 1
      fi
    '';

  # `import <mod>` smoke-test: the runtime counterpart to the static
  # `self-contained` guard below.
  importTest = e:
    runPython {
      name = "wheel-import-${e.attr}";
      wheel = python3.pkgs.${e.attr};
      script = "import ${pyImportOf e}";
    };

  # Static guard: a wheel must not bake a /nix/store path it loads at runtime
  # (ctypes/cffi .so, a spawned binary) - that path won't exist on a bare wasix
  # pip target, so the wheel would import/run only under a store mount. Bundle
  # the artifact instead (overlay/python-packages/lib/bundle.nix). Excludes, as
  # non-runtime: .dist-info metadata (provenance), line-1 shebangs (a lib is
  # never exec'd), and the eeee-sanitized build paths recorded by some configs.
  selfContainedTest = e: let
    wheel = python3.pkgs.${e.attr};
  in
    pkgs.runCommand "wheel-selfcontained-${e.attr}" {} ''
      site="${wheel}/${python3.sitePackages}"
      hits=$(${pkgs.gnugrep}/bin/grep -rnaE '/nix/store/[a-z0-9]{32}-' "$site" --include='*.py' \
        | ${pkgs.gnugrep}/bin/grep -vE '\.dist-info/' \
        | ${pkgs.gnugrep}/bin/grep -vE ':1:#!' \
        | ${pkgs.gnugrep}/bin/grep -v 'eeeeeeeeeeeeeeee' || true)
      if [ -n "$hits" ]; then
        echo "wheel '${e.attr}' embeds runtime /nix/store paths (breaks pip on a bare wasix target):" >&2
        echo "$hits" >&2
        echo "-> bundle the artifact into the wheel, see overlay/python-packages/lib/bundle.nix" >&2
        exit 1
      fi
      echo "OK ${e.attr}" > "$out"
    '';

  # Guards a `noarch` mark (a python-version-independent package, e.g. a redistributed binary): the
  # wheel AND its whole python-dep closure must be py3-none-any. A version-specific (cp-tagged)
  # member builds only on the default python, so the other interpreter can't resolve it from the
  # merged registry. Runs on the default python.
  noarchClosureTest = e: let
    wheel = python3.pkgs.${e.attr};
    members = lib.filter (m: m ? dist) ([wheel] ++ python3.pkgs.requiredPythonModules [wheel]);
  in
    pkgs.runCommand "wheel-noarch-closure-${e.attr}" {} ''
      fail=
      for dist in ${lib.escapeShellArgs (map (m: "${m.dist}") members)}; do
        whl=$(${pkgs.findutils}/bin/find "$dist" -name '*.whl' | head -1)
        case "$(basename "$whl")" in
          *-py3-none-any.whl | *-py2.py3-none-any.whl) ;;
          *)
            echo "noarch '${e.attr}': closure member $(basename "$whl") is version-specific" >&2
            fail=1
            ;;
        esac
      done
      if [ -n "$fail" ]; then
        echo "-> a noarch wheel's whole closure must be py3-none-any; make the dep noarch or drop the mark." >&2
        exit 1
      fi
      echo "OK ${e.attr}: closure all py3-none-any" > "$out"
    '';

  # Per-package behavioural tests: overlay/python-packages/<attr>/tests/*.nix, each
  # a function over a subset of {wheel, runPython, lib} returning named test
  # derivations, folded into the wheel's test group -- the wheel analogue of the
  # wasmer packages/<name>/tests/ convention.
  pkgTestsDir = attr: ./overlay/python-packages + "/${attr}/tests";
  pkgTests = e: let
    dir = pkgTestsDir e.attr;
    scope = {
      wheel = python3.pkgs.${e.attr};
      inherit runPython lib;
    };
  in
    builtins.foldl' (
      acc: fname: let
        f = import (dir + "/${fname}");
      in
        acc // f (builtins.intersectAttrs (lib.functionArgs f) scope)
    ) {}
    (lib.attrNames (lib.filterAttrs
      (n: t: t == "regular" && lib.hasSuffix ".nix" n && n != "helpers.nix")
      (builtins.readDir dir)));

  # python3.pkgs.<attr> with .tests added (passthru-only, so the store path is
  # unchanged). Inherited nixpkgs passthru.tests are dropped: they are x86 test
  # suites that would leak into `checks`.
  mkWheel = e:
    (python3.pkgs.${e.attr}).overrideAttrs (o: {
      passthru =
        removeAttrs (o.passthru or {}) ["tests"]
        // lib.optionalAttrs (!(e.skipTest or false)) {
          tests = mkTestGroup "wheel-${e.attr}" ({
              import = importTest e;
              self-contained = selfContainedTest e;
            }
            // lib.optionalAttrs (e.noarch or false) {noarch-closure = noarchClosureTest e;}
            // lib.optionalAttrs (builtins.pathExists (pkgTestsDir e.attr)) (pkgTests e));
        };
    });
in
  lib.listToAttrs (map (e: lib.nameValuePair e.attr (mkWheel e)) (lib.filter select wheelList))
