#!/usr/bin/env bash
# This script builds all packages in the flake, signs them, and pushes them to the S3 cache.
# It expects the following environment variables to be set:
# - NIX_SIGNING_KEY: The secret key for signing Nix store paths
# - AWS_ACCESS_KEY_ID: S3 access key
# - AWS_SECRET_ACCESS_KEY: S3 secret key

set -euxo pipefail

# Check that required env vars are set.
for var in NIX_SIGNING_KEY AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY; do
    if [ -z "${!var:-}" ]; then
        echo "ERROR: Required environment variable $var is not set."
        exit 1
    fi
done

BUCKET="wasinix-cache"
ENDPOINT="https://1541b1e8a3fc6ad155ce67ef38899700.r2.cloudflarestorage.com"
PUBLIC_URL="https://nix-cache.wasix.org"
CACHE_PUB_KEY="wasinix-1:jvsqbOJGsZxMvg97fuyNCWCc+t2nn6uHB47kQCGNmXI="
CACHE_STORE="s3://$BUCKET?region=auto&endpoint=$ENDPOINT&compression=zstd"

echo "Determining system..."
SYSTEM=$(nix eval --raw --impure --accept-flake-config --expr 'builtins.currentSystem')
echo "Building all packages for $SYSTEM..."
echo "Effective Nix cache config:"
nix config show | sed -n '/^substituters =/p; /^trusted-public-keys =/p; /^trusted-users =/p'

# Build and get output paths
# We use --json to reliably extract the output paths of all packages
PATHS=$(nix build .#packages."$SYSTEM".wasixAll .#packages."$SYSTEM".wasmerAll \
    --accept-flake-config \
    --option extra-substituters "$PUBLIC_URL" \
    --option extra-trusted-public-keys "$CACHE_PUB_KEY" \
    --json --no-link --print-build-logs | jq -r '.[].outputs | to_entries[].value')

if [ -z "$PATHS" ]; then
    echo "No paths built, nothing to push."
    exit 0
fi

echo "Signing paths..."
SIGNING_KEY_FILE=$(mktemp)
trap 'rm -f "$SIGNING_KEY_FILE"' EXIT
echo "$NIX_SIGNING_KEY" > "$SIGNING_KEY_FILE"
chmod 600 "$SIGNING_KEY_FILE"
ACTUAL_PUB_KEY=$(nix key convert-secret-to-public < "$SIGNING_KEY_FILE")
if [ "$ACTUAL_PUB_KEY" != "$CACHE_PUB_KEY" ]; then
    echo "ERROR: NIX_SIGNING_KEY does not match CACHE_PUB_KEY."
    echo "Expected: $CACHE_PUB_KEY"
    echo "Actual:   $ACTUAL_PUB_KEY"
    exit 1
fi
# shellcheck disable=SC2086
nix store sign --key-file "$SIGNING_KEY_FILE" $PATHS

echo "Pushing to $PUBLIC_URL..."

# echo "Clearing local Nix binary-cache metadata cache..."
# rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/nix/binary-cache-v"*.sqlite*
# shellcheck disable=SC2086

nix copy --repair --debug --to "$CACHE_STORE&secret-key=$SIGNING_KEY_FILE" $PATHS

# FIRST_PATH=$(printf '%s\n' $PATHS | sed -n '1p')
# FIRST_HASH=$(basename "$FIRST_PATH" | cut -d- -f1)
# NARINFO_URL="$PUBLIC_URL/$FIRST_HASH.narinfo"
# echo "Verifying uploaded narinfo at $NARINFO_URL..."
# NARINFO=$(curl -fsSL "$NARINFO_URL")
# printf '%s\n' "$NARINFO" | sed -n '/^StorePath:/p; /^URL:/p; /^Sig:/p'
# if ! printf '%s\n' "$NARINFO" | grep -q '^Sig: wasinix-1:'; then
#     echo "ERROR: Uploaded narinfo is missing the expected wasinix-1 signature."
#     exit 1
# fi

echo "Successfully pushed all packages to cache."
