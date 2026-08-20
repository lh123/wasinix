{
  pkgs,
  testLib,
  helpers,
  preferredProfilePackages,
}:
helpers.forEachPython preferredProfilePackages ({
  python,
  pyVer,
  tag,
}: {
  runtime-layout = testLib.mkWasixRun {
    name = "python${tag}-runtime-layout";
    wasixPkgs = [python];
    script = ''
      unset PYTHONHOME
      python${pyVer} - <<'PY' | tee out.log
      import os
      import sys
      import sysconfig

      assert "PYTHONHOME" not in os.environ
      assert sys.executable == "/usr/local/bin/python${pyVer}.wasm"
      assert sys.prefix == "/usr/local"
      assert sys.base_prefix == "/usr/local"
      assert sysconfig.get_path("stdlib") == "/usr/local/lib/python${pyVer}"
      assert sysconfig.get_config_var("prefix") == "/usr/local"
      assert sysconfig.get_config_var("TZPATH") == "/usr/share/zoneinfo"
      print("RUNTIME_LAYOUT_OK")
      PY
      grep -q RUNTIME_LAYOUT_OK out.log
    '';
  };
})
