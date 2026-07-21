#!/usr/bin/env python3
# Primitives shared by scripts/update.py (the driver) and the per-package
# update scripts that sync a derived pin after their own bump
# (pkgs/toolchain/*/update.py). Import via bootstrap(), which finds the
# checkout the way update.py does: `nix run` puts the caller in the store, but
# the pins being edited are in the working tree.

import json
import subprocess
import sys
from pathlib import Path
from urllib import request


def repo_root():
    try:
        out = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            check=True,
            text=True,
            capture_output=True,
        )
        return Path(out.stdout.strip())
    except (subprocess.CalledProcessError, FileNotFoundError):
        return Path(__file__).resolve().parent.parent


REPO = repo_root()


def bootstrap():
    """Put scripts/ on sys.path so a package's update.py can import this from
    anywhere in the tree, then hand back the checkout root."""
    p = str(REPO / "scripts")
    if p not in sys.path:
        sys.path.insert(0, p)
    return REPO


def run(cmd, **kw):
    print(f"  $ {' '.join(cmd)}", file=sys.stderr)
    p = subprocess.run(cmd, text=True, capture_output=True, **kw)
    if p.returncode != 0:
        raise RuntimeError(
            f"{cmd[0]} exited {p.returncode}:\n{(p.stderr or p.stdout).strip()}"
        )
    return p


def gh(path):
    req = request.Request(f"https://api.github.com/repos/{path}")
    req.add_header("Accept", "application/vnd.github+json")
    with request.urlopen(req) as r:
        return json.load(r)


def raw_file(owner, repo, rev, path):
    url = f"https://raw.githubusercontent.com/{owner}/{repo}/{rev}/{path}"
    with request.urlopen(url) as r:
        return r.read().decode()


def prefetch_url(url):
    out = run(["nix", "store", "prefetch-file", "--json", url])
    return json.loads(out.stdout)["hash"]


def prefetch_github(owner, repo, rev):
    url = f"https://github.com/{owner}/{repo}/archive/{rev}.tar.gz"
    out = run(["nix", "store", "prefetch-file", "--json", "--unpack", url])
    return json.loads(out.stdout)["hash"]


def run_nix_update(argv):
    """Run the nix-update command the package declared, streaming its output.
    The driver passes it as our argv, so the package keeps using
    nix-update-script rather than restating its arguments here."""
    if not argv:
        raise SystemExit("no nix-update command passed")
    p = subprocess.run(argv, cwd=REPO, text=True, capture_output=True)
    sys.stderr.write(p.stderr)
    sys.stdout.write(p.stdout)
    if p.returncode != 0:
        raise SystemExit(f"{argv[0]} exited {p.returncode}")
