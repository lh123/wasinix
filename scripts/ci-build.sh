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

# --copy-to pushes only runtime closures, so build-only deps (pkg-config wrapper
# + hooks, vendor dirs) never get cached -> next run sees those packages as
# uncached and re-pulls everything. Capture them now (must be pre-build: once
# built they read "local", not "notBuilt") and push after the build realises them.
PUSH_DRVS=""
if [ -n "${NIX_SIGNING_KEY:-}" ]; then
  PUSH_DRVS=$(
    nix run nixpkgs#nix-eval-jobs -- \
      --flake "$CI_ATTR" --check-cache-status --option accept-flake-config true 2>/dev/null |
      jq -r '.neededBuilds[]?' | sort -u
  )
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
status=$?

# copy-to above already pushed the runtime closures during the build; this is
# the build-only half it can't reach. Here we just push the captured deps' outputs.
# copy --to skips already cached paths, so this is a no-op if cache is warm already.
if [ -n "${NIX_SIGNING_KEY:-}" ] && [ -n "$PUSH_DRVS" ]; then
  outs=$(
    printf '%s\n' "$PUSH_DRVS" | xargs -r nix-store --query --outputs 2>/dev/null |
      while read -r p; do [ -n "$p" ] && [ -e "$p" ] && printf '%s\n' "$p"; done
  )
  if [ -n "$outs" ]; then
    echo "Pushing $(printf '%s\n' "$outs" | wc -l) build-time paths --copy-to misses..."
    # shellcheck disable=SC2086
    nix copy --to "$CACHE_STORE&secret-key=$KEY_FILE" $outs ||
      echo "WARN: build-dep push failed (non-fatal)." >&2
  fi
fi

exit "$status"
