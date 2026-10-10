# nixpkgs' pip generates shell completions by executing $out/bin/pip, whose
# shebang is the guest interpreter path; a cross build cannot run it, so the
# completions come out empty and installShellCompletion fails. Keep the man page.
{
  pyprev,
  ...
}:
pyprev.pip.overrideAttrs (_: {
  postInstall = ''
    installManPage docs/build/man/*
  '';
})
