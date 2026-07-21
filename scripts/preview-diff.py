#!/usr/bin/env python3
"""Diff two checkouts' wheel and webc build plans, for PR previews.

Prints JSON {"wheels": [...], "webcs": [...]}: the head checkout's distsJson
entries whose wheel drvPath differs from (or is absent in) the base checkout,
and the webc names whose package drvPath moved. Run from the head checkout:
preview-diff.py <base-checkout-dir>
"""

import json
import subprocess
import sys

SYSTEM = "x86_64-linux"


def ev(flake: str, attr: str, apply: str | None = None):
    cmd = ["nix", "eval", "--json", f"{flake}#legacyPackages.{SYSTEM}.{attr}"]
    if apply:
        cmd += ["--apply", apply]
    p = subprocess.run(cmd, text=True, capture_output=True)
    if p.returncode != 0:
        raise SystemExit(f"eval of {flake}#{attr} failed:\n{p.stderr.strip()}")
    return json.loads(p.stdout)


def dists(flake: str) -> dict[str, dict]:
    return {d["attr"]: d for d in json.loads(ev(flake, "pythonRegistry.distsJson"))}


# attr is the wasmerPackages key (jq-1.6.0 for history entries), name the
# webc name it publishes under (jq)
WEBC_DRVS = (
    "ws: builtins.mapAttrs (_: p: "
    "{drv = p.pkg.drvPath; name = p.pkg.id.name; version = p.pkg.id.baseVersion;}) ws"
)


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: preview-diff.py <base-checkout-dir>")
    base = f"path:{sys.argv[1]}"

    head_d, base_d = dists("."), dists(base)
    wheels = [
        d
        for attr, d in sorted(head_d.items())
        if base_d.get(attr, {}).get("drvPath") != d["drvPath"]
    ]
    head_w = ev(".", "wasmerPackages", WEBC_DRVS)
    base_w = ev(base, "wasmerPackages", WEBC_DRVS)
    webcs = [
        {"attr": a, "name": w["name"], "version": w["version"]}
        for a, w in sorted(head_w.items())
        if base_w.get(a, {}).get("drv") != w["drv"]
    ]

    json.dump({"wheels": wheels, "webcs": webcs}, sys.stdout, indent=2)
    print()


if __name__ == "__main__":
    main()
