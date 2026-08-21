# runtimeShellPackage null: don't pull a target-side bash-static.
{
  final,
  prev,
  helpers,
  ...
}: let
  wrappers = final.runCommand "gzip-shell-wrappers" {} ''
    mkdir -p "$out/bin"
    cat > "$out/bin/gunzip" <<'EOF'
    #!/bin/bash
    exec gzip -d "$@"
    EOF
    cat > "$out/bin/zcat" <<'EOF'
    #!/bin/bash
    exec gzip -cd "$@"
    EOF
    chmod +x "$out/bin/gunzip" "$out/bin/zcat"
  '';
in
helpers.wasmRename {wasmName = "gzip";} (
  helpers.libTweaks {
    passthru.wasix.shipped = true;
    passthru.wasmer.fs."/usr/local" = wrappers;
    # Drop nixpkgs' preFixup: it PATH-injects its gunzip/zcat shell scripts and
    # wrapProgram's bin/gzip, which wasmRename renames to gzip.wasm.
    preFixup = _: "";
    postInstall = ''
      rm -f "$out/bin/gunzip" "$out/bin/zcat"
    '';
  } (prev.gzip.override {runtimeShellPackage = null;})
)
