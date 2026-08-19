#!/usr/bin/env bash
set -euo pipefail

package="$(git rev-parse --show-toplevel)/pkgs/products/wasix-llvm/package.nix"

wasinix update nix-update -- "$@"

version=$(sed -n '0,/version = "/s/.*version = "\([^"]*\)".*/\1/p' "$package")
block='/bindist = pkgs.fetchurl {/,/^  };/p'
old_hash=$(sed -n "$block" "$package" | sed -n 's/.*hash = "\([^"]*\)".*/\1/p')
url="https://github.com/wasix-org/llvm-project/releases/download/$version/LLVM-Linux-x86_64.tar.gz"
new_hash=$(nix store prefetch-file --json "$url" | jq -r .hash)

sed -i "/bindist = pkgs.fetchurl {/,/^  };/s|hash = \"$old_hash\"|hash = \"$new_hash\"|" "$package"
grep -qF "hash = \"$new_hash\"" "$package" || {
  echo "LLVM bindist hash rewrite failed" >&2
  exit 1
}

echo "LLVM bindist synced to $version"
