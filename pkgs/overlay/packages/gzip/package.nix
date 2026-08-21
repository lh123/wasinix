# runtimeShellPackage null: don't pull a target-side bash-static.
{
  final,
  prev,
  helpers,
  ...
}: let
  wrappers = final.runCommand "gzip-shell-wrappers" {} ''
    mkdir -p "$out"
    cat > "$out/gunzip" <<'EOF'
    #!/bin/bash
    exec gzip -d "$@"
    EOF
    cat > "$out/zcat" <<'EOF'
    #!/bin/bash
    exec gzip -cd "$@"
    EOF
    chmod +x "$out/gunzip" "$out/zcat"
  '';
in
helpers.wasmRename {wasmName = "gzip";} (
  helpers.libTweaks {
    passthru.wasix.shipped = true;
    # The aggregate sandbox provides bash and the gzip command at /bin.
    passthru.wasmer.fs."/bin" = wrappers;
    # Drop nixpkgs' preFixup: it PATH-injects its gunzip/zcat shell scripts and
    # wrapProgram's bin/gzip, which wasmRename renames to gzip.wasm.
    preFixup = _: "";
    postInstall = ''
      rm -f "$out/bin/gunzip" "$out/bin/zcat"
    '';
  } (prev.gzip.override {runtimeShellPackage = null;})
)
