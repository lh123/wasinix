#!/usr/bin/env bash
# Deploy a built preview index as an ephemeral Edge app (PR previews): a
# static-web-server package with the site embedded, one app per PR, deleted by
# preview-cleanup.yml when the PR closes. Prints the app URL last.
# Usage: preview-index-deploy.sh <site-dir> <app-name>. Env: WASMER_REGISTRY
# (default wasmer.io), APP_OWNER (default wasmer), WASMER_TOKEN for auth.
set -euo pipefail

site="${1:?usage: preview-index-deploy.sh <site-dir> <app-name>}"
app="${2:?usage: preview-index-deploy.sh <site-dir> <app-name>}"
registry="${WASMER_REGISTRY:-wasmer.io}"
owner="${APP_OWNER:-wasmer}"

dir=$(mktemp -d)
cp -r --no-preserve=mode,ownership "$site" "$dir/site"
cat >"$dir/wasmer.toml" <<EOF
[dependencies]
"wasmer/static-web-server" = "*"

[fs]
"/public" = "site"
EOF
cat >"$dir/app.yaml" <<EOF
kind: wasmer.io/App.v0
name: $app
owner: $owner
package: .
EOF

# --no-wait: an ephemeral preview does not need the reachability poll, which
# errored after 5 minutes on a fresh app even though the deploy succeeded
(cd "$dir" && wasmer deploy --non-interactive --no-wait --registry "$registry" >&2)
wasmer app get "$owner/$app" --registry "$registry" --format json | jq -r .url
