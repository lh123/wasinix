#!/usr/bin/env bash
# This script builds all packages in the flake, signs them, and pushes them to the S3 cache.
# It expects the following environment variables to be set:
# - NIX_SIGNING_KEY: The secret key for signing Nix store paths
# - AWS_ACCESS_KEY_ID: S3 access key
# - AWS_SECRET_ACCESS_KEY: S3 secret key

set -euo pipefail

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

echo "Signing paths..."
SIGNING_KEY_FILE=$(mktemp)
echo "$NIX_SIGNING_KEY" > "$SIGNING_KEY_FILE"
# shellcheck disable=SC2086
nix store sign --key-file "$SIGNING_KEY_FILE" $PATHS
rm "$SIGNING_KEY_FILE"

echo "Pushing to $PUBLIC_URL..."
# shellcheck disable=SC2086
nix copy --to "s3://$BUCKET?region=auto&endpoint=$ENDPOINT&compression=zstd" $PATHS

echo "Successfully pushed all packages to cache."
