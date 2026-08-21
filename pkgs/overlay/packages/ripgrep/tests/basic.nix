{
  testLib,
  wasmerPkgs,
  ...
}: {
  version = testLib.mkWasixRun {
    name = "rg-version";
    wasixPkgs = [wasmerPkgs.rg];
    script = "rg --version";
  };

  recursive = testLib.mkWasixRun {
    name = "rg-recursive";
    wasixPkgs = [wasmerPkgs.rg];
    script = ''
      mkdir -p tree/sub
      printf 'hit\n' > tree/a.txt
      printf 'miss\n' > tree/sub/b.txt
      printf 'hit\n' > tree/sub/c.txt
      [ "$(rg -l hit tree | sort)" = $'tree/a.txt\ntree/sub/c.txt' ]
    '';
  };
}
