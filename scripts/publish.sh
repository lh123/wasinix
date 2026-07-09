#!/usr/bin/env bash
# Provision-or-fetch the index volume's S3 credentials, then publish the built
# registry. Run via `nix run .#scripts.publish`, which provides the patched
# wasmer, rclone, and python3. Env: WASMER_APP, INDEX_VOLUME (+ WASMER_TOKEN for
# auth). Args: --registry <path> [--rev <sha>].
set -euo pipefail

registry="" rev=""
while [ $# -gt 0 ]; do
  case "$1" in
  --registry)
    registry="$2"
    shift 2
    ;;
  --rev)
    rev="$2"
    shift 2
    ;;
  *)
    echo "unknown arg: $1" >&2
    exit 1
    ;;
  esac
done
[ -n "$registry" ] || {
  echo "--registry required" >&2
  exit 1
}

# The R2 nix-cache credentials are present in the CI env; rclone's S3 backend
# would pick these up ahead of the volume's own config creds and fail writes
# with SignatureDoesNotMatch. The volume auth comes only from the rclone config
# section below, so clear any ambient AWS creds.
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN \
  AWS_DEFAULT_REGION AWS_REGION AWS_ENDPOINT_URL AWS_ENDPOINT_URL_S3

block=$(mktemp)
mkdir -p ~/.config/rclone
# the credentials read path works once provisioned; the first run has none, so
# provision with the patched rotate-secrets (per AppVolume) and read again.
# rotate prints the creds on stdout, so discard it and re-read into a file to
# keep them out of the log.
if ! wasmer app volume credentials "$WASMER_APP" --registry wasmer.io --format rclone >"$block" 2>/dev/null; then
  wasmer app volume rotate-secrets "$WASMER_APP" --volume "$INDEX_VOLUME" --registry wasmer.io >/dev/null
  wasmer app volume credentials "$WASMER_APP" --registry wasmer.io --format rclone >"$block"
fi
cat "$block" >>~/.config/rclone/rclone.conf

# the section name the credentials snippet defines (edge-<app>-<volume>); parse
# it rather than reconstruct, since the CLI mangles the volume into it.
remote=$(sed -n 's/^\[\(.*\)\]$/\1/p' "$block" | head -1)
[ -n "$remote" ] || {
  echo "no rclone remote section in the credentials output" >&2
  exit 1
}

# TEMP DEBUG: capture what actually gets signed for a single small PUT.
{
  echo "=== s3/aws env (redacted) ==="
  env | grep -iE 'aws_|s3_|rclone_|_proxy' | sed -E 's/=.+/=<set>/' || echo "(none)"
  echo "=== config access-key prefix ==="
  rclone config show "$remote" | grep -iE 'access_key_id|type|endpoint|region|provider' |
    sed -E 's/(access_key_id = .{5}).*/\1…/'
  echo "=== verbose single-file probe ==="
  printf 'probe\n' >/tmp/ci-probe
  rclone copy -vv --ignore-times /tmp/ci-probe "$remote:$INDEX_VOLUME/ci-probe/"
} >&2 || echo "PROBE FAILED (see -vv above)" >&2
# END DEBUG

python3 pkgs/python-registry/publish.py \
  --registry "$registry" \
  --remote "$remote:$INDEX_VOLUME" \
  --rev "$rev"
