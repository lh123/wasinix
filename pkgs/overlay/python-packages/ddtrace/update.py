#!/usr/bin/env python3
# Bump ddtrace, then re-derive the pin that follows from it.
#
# ddtrace bundles libddwaf's .so (no wasm release to download), so our libddwaf
# must be exactly the LIBDDWAF_VERSION the new setup.py expects. That version is
# ddtrace's to dictate, so libddwaf carries no updateScript of its own and is
# bumped from here.
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
    prefetch_github,
    raw_file,
    run_nix_update,
)

DDTRACE = REPO / "pkgs/overlay/python-packages/ddtrace/package.nix"
LIBDDWAF = REPO / "pkgs/overlay/packages/libddwaf/package.nix"


def sync_libddwaf():
    version = re.search(r'version = "([^"]+)"', DDTRACE.read_text()).group(1)
    setup = raw_file("DataDog", "dd-trace-py", f"v{version}", "setup.py")
    m = re.search(r'^LIBDDWAF_VERSION\s*=\s*"([^"]+)"', setup, re.M)
    if not m:
        raise SystemExit(
            f"LIBDDWAF_VERSION not found in dd-trace-py v{version} setup.py; "
            "upstream moved it, so the libddwaf pairing needs re-deriving by hand"
        )
    want = m.group(1)

    text = LIBDDWAF.read_text()
    cur = re.search(r'version = "([^"]+)"', text).group(1)
    if cur == want:
        return None
    old_hash = re.search(r'hash = "(sha256-[A-Za-z0-9+/=]+)"', text).group(1)
    # libddwaf tags are the bare version (tag = finalAttrs.version)
    new_hash = prefetch_github("DataDog", "libddwaf", want)
    text = text.replace(f'version = "{cur}"', f'version = "{want}"', 1)
    text = text.replace(old_hash, new_hash, 1)
    LIBDDWAF.write_text(text)
    return f"{cur} to {want}"


def main():
    run_nix_update(sys.argv[1:])
    synced = sync_libddwaf()
    # No " -> ": the driver scans stdout backwards for an outcome line and must
    # land on nix-update's, not this one.
    print(f"libddwaf bumped {synced}" if synced else "libddwaf pin ok")


if __name__ == "__main__":
    main()
