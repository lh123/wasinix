#!/usr/bin/env python3
# Bump the wasix rust fork, then re-derive the pin that follows from it.
#
# The stage0 bootstrap pin follows from the new fork tag. That is package
# knowledge, not driver knowledge, so it lives next to the pin it edits. The
# cargo vendor hash follows too, but nix-update re-derives that one itself off
# passthru.cargoDeps.
#
# Invoked as `update.py <nix-update ...>`: the driver passes the command
# nix-update-script produced, so the package declares its bump once.

import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(
    0,
    str(
        Path(
            subprocess.run(
                ["git", "rev-parse", "--show-toplevel"],
                text=True,
                capture_output=True,
                check=True,
            ).stdout.strip()
        )
        / "scripts"
    ),
)
from updater_lib import (  # noqa: E402
    REPO,
    prefetch_url,
    raw_file,
    run_nix_update,
)

TOOLCHAIN = REPO / "pkgs/toolchain/rust/toolchain.nix"


def version(text):
    return re.search(r'\bversion = "([^"]+)"', text).group(1)


def sync_stage0():
    text = TOOLCHAIN.read_text()
    rust_version = version(text)
    stage0 = raw_file("wasix-org", "rust", f"v{rust_version}", "src/stage0")
    kv = dict(re.findall(r"^(\w+)=(.+)$", stage0, re.M))
    date, ver, server = kv["compiler_date"], kv["compiler_version"], kv["dist_server"]

    cur = re.search(
        r'pname = "rust-bootstrap";\s*\n\s*version = "([^"]+)"', text
    ).group(1)
    if cur == ver:
        return None

    url_literal = f"{server}/dist/{date}/rust-{ver}-${{hostTriple}}.tar.xz"
    new_hash = prefetch_url(
        f"{server}/dist/{date}/rust-{ver}-x86_64-unknown-linux-gnu.tar.xz"
    )
    old_hash = re.search(
        r'rust-bootstrap";.*?(sha256-[A-Za-z0-9+/=]+)', text, re.S
    ).group(1)

    text = re.sub(
        r'(pname = "rust-bootstrap";\s*\n\s*version = ")[^"]+(")',
        rf"\g<1>{ver}\g<2>",
        text,
    )
    text = re.sub(r'url = "[^"]*rust-[^"]*\.tar\.xz";', f'url = "{url_literal}";', text)
    text = text.replace(old_hash, new_hash, 1)
    TOOLCHAIN.write_text(text)
    return f"{ver} ({date})"


def main():
    run_nix_update(sys.argv[1:])
    synced = sync_stage0()
    # No " -> ": the driver scans stdout backwards for an outcome line and must
    # land on nix-update's, not this one.
    print(f"stage0 bootstrap synced to {synced}" if synced else "stage0 bootstrap ok")


if __name__ == "__main__":
    main()
