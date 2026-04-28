#!/usr/bin/env bash
set -euo pipefail

# This script builds all packages in the flake, signs them, and pushes them to the S3 cache.
# It expects the following environment variables to be set:
# - NIX_SIGNING_KEY: The secret key for signing Nix store paths
# - AWS_ACCESS_KEY_ID: S3 access key
# - AWS_SECRET_ACCESS_KEY: S3 secret key

BUCKET="wasinix-cache"
ENDPOINT="https://1541b1e8a3fc6ad155ce67ef38899700.r2.cloudflarestorage.com"
PUBLIC_URL="https://nix-cache.wasix.org"

echo "Determining system..."
SYSTEM=$(nix eval --raw --impure --expr 'builtins.currentSystem')
echo "Building all packages for $SYSTEM..."

# Build and get output paths
# We use --json to reliably extract the output paths of all packages
PATHS=$(nix build .#packages."$SYSTEM".wasixAll .#packages."$SYSTEM".wasmerAll --json --no-link --print-build-logs | jq -r '.[].outputs | to_entries[].value')

if [ -z "$PATHS" ]; then
    echo "No paths built, nothing to push."
    exit 0
fi

if [ -n "${NIX_SIGNING_KEY:-}" ]; then
    echo "Signing paths..."
    SIGNING_KEY_FILE=$(mktemp)
    echo "$NIX_SIGNING_KEY" > "$SIGNING_KEY_FILE"
    # shellcheck disable=SC2086
    nix store sign --key-file "$SIGNING_KEY_FILE" $PATHS
    rm "$SIGNING_KEY_FILE"
else
    echo "ERROR: NIX_SIGNING_KEY not set."
    exit 1
fi

echo "Pushing to $PUBLIC_URL..."
# shellcheck disable=SC2086
nix copy --to "s3://$BUCKET?region=auto&endpoint=$ENDPOINT&compression=zstd" $PATHS

echo "Successfully pushed all packages to cache."
