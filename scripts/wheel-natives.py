#!/usr/bin/env python3
"""Count served wheels that ship compiled extension modules.

Scans a built index (`nix build .#pythonRegistry`, or the path given as an
argument): a wheel is native when it contains a .so, which on this target is a
wasm32 extension module. Counts both wheel files (one per interpreter and
served version) and distinct projects.

Usage:
  wheel-natives.py [<registry>] [--list] [--json]
"""

import argparse
import json
import subprocess
import sys
import zipfile
from pathlib import Path


def build_registry() -> Path:
    out = subprocess.run(
        ["nix", "build", "--no-link", "--print-out-paths", ".#pythonRegistry"],
        check=True,
        stdout=subprocess.PIPE,
        text=True,
    ).stdout.split()
    return Path(out[-1])


def is_native(whl: Path) -> bool:
    with zipfile.ZipFile(whl) as zf:
        names = zf.namelist()
        if any(n.endswith(".so") for n in names):
            return True
        # a bundled binary carries no telling suffix (pypandoc ships `files/pandoc`)
        for n in names:
            if n.endswith("/"):
                continue
            with zf.open(n) as f:
                if f.read(4) == b"\0asm":
                    return True
    return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "registry", nargs="?", help="built index (default: build .#pythonRegistry)"
    )
    ap.add_argument("--list", action="store_true", help="also print the project names")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    root = Path(args.registry) if args.registry else build_registry()
    simple = root / "simple"
    if not simple.is_dir():
        sys.exit(f"{root}: no simple/ dir, not a python index")

    native, pure = {}, {}
    for whl in sorted(simple.glob("*/*.whl")):
        bucket = native if is_native(whl) else pure
        bucket.setdefault(whl.parent.name, []).append(whl.name)

    files = sum(map(len, native.values())), sum(map(len, pure.values()))
    if args.json:
        json.dump(
            {
                "registry": str(root),
                "native": {"projects": sorted(native), "files": files[0]},
                "pure": {"projects": sorted(pure), "files": files[1]},
            },
            sys.stdout,
            indent=2,
        )
        print()
        return

    projects = len(native) + len(pure)
    print(f"{root}")
    print(f"native: {len(native):4} / {projects} projects, {files[0]} wheel files")
    print(f"pure:   {len(pure):4} / {projects} projects, {files[1]} wheel files")
    if args.list:
        print("\nnative projects:")
        for name in sorted(native):
            print(f"  {name}")


if __name__ == "__main__":
    main()
