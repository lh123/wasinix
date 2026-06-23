#!/usr/bin/env bash
# Build every CI package independently, emitting a JUnit report (one test case
# per package). With a signing key present it signs and uploads each package to
# the cache as it builds (--copy-to, with --retries for transient blips), so a
# timeout/cancel never loses built work.
# Without a key (e.g. fork PR) it just builds. A down cache only slows builds.

set -uo pipefail # no -e: keep building past failures

ENDPOINT="https://1541b1e8a3fc6ad155ce67ef38899700.r2.cloudflarestorage.com"
CACHE_STORE="s3://wasinix-cache?region=auto&endpoint=$ENDPOINT&compression=zstd"
CACHE_PUB_KEY="wasinix-1:jvsqbOJGsZxMvg97fuyNCWCc+t2nn6uHB47kQCGNmXI="

CI_ATTR="${CI_ATTR:-.#legacyPackages.$(nix eval --raw --impure --expr 'builtins.currentSystem').ci}"
RESULT_FILE="${RESULT_FILE:-nix-fast-build-result.xml}"

COPY_ARGS=()
if [ -n "${NIX_SIGNING_KEY:-}" ]; then
  KEY_FILE=$(mktemp)
  chmod 600 "$KEY_FILE"
  trap 'rm -f "$KEY_FILE"' EXIT
  printf '%s\n' "$NIX_SIGNING_KEY" >"$KEY_FILE"
  pub=$(nix key convert-secret-to-public <"$KEY_FILE")
  if [ "$pub" != "$CACHE_PUB_KEY" ]; then
    echo "ERROR: NIX_SIGNING_KEY does not match CACHE_PUB_KEY ($pub)" >&2
    exit 1
  fi
  COPY_ARGS=(--copy-to "$CACHE_STORE&secret-key=$KEY_FILE")
  echo "Incremental cache upload enabled."
else
  echo "No signing key — building without cache upload."
fi

echo "Building all packages under $CI_ATTR independently..."

# --skip-cached: on a warm cache only changed packages rebuild.
nix run nixpkgs#nix-fast-build -- \
  --flake "$CI_ATTR" \
  --skip-cached \
  --retries 3 \
  --no-nom \
  --no-link \
  --result-file "$RESULT_FILE" \
  --result-format junit \
  --option accept-flake-config true \
  "${COPY_ARGS[@]}"
