{
  wasmerPkgs,
  testLib,
  ...
}: {
  path-command = testLib.mkWasixRun {
    name = "which-path-command";
    wasixPkgs = [wasmerPkgs.which wasmerPkgs.coreutils];
    script = ''
      [ "$(PATH=/bin:/usr/local/bin which cut)" = "/bin/cut" ]
      echo which-ok
    '';
  };
}
