#!/bin/bash
# Build, notarize, and upload the DMG to the GitHub release asset.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TAG="${TAG:-v1.0.0}"
ASSET_NAME="${ASSET_NAME:-Ctrl+Brain-1.0.dmg}"
REPO="${REPO:-yug-space/ctrl-brain}"
NOTARY_KEYCHAIN_PROFILE="${NOTARY_KEYCHAIN_PROFILE:-ctrlbrain-notary}" ./package-dmg.sh

DMG="$ROOT/dist/$ASSET_NAME"
if [ ! -f "$DMG" ]; then
    echo "error: DMG not found: $DMG" >&2
    exit 1
fi

CRED=$(printf 'protocol=https\nhost=github.com\n\n' | git credential fill)
TOKEN=$(printf '%s\n' "$CRED" | awk -F= '/^password=/{print substr($0,10)}')
if [ -z "$TOKEN" ]; then
    echo "error: no GitHub token available from git credential helper" >&2
    exit 1
fi

API="https://api.github.com/repos/$REPO"
AUTH=(-H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28")
RELEASE=$(curl -fsS "${AUTH[@]}" "$API/releases/tags/$TAG" || true)

if printf '%s' "$RELEASE" | jq -e '.id' >/dev/null 2>&1; then
    UPLOAD_URL=$(printf '%s' "$RELEASE" | jq -r '.upload_url' | sed 's/{.*//')
    ASSETS_URL=$(printf '%s' "$RELEASE" | jq -r '.assets_url')
else
    COMMIT=$(git rev-parse HEAD)
    BODY="Developer ID signed and notarized macOS DMG for Ctrl+Brain."
    RELEASE=$(jq -n \
        --arg tag "$TAG" \
        --arg commit "$COMMIT" \
        --arg name "Ctrl+Brain ${TAG#v}" \
        --arg body "$BODY" \
        '{tag_name:$tag,target_commitish:$commit,name:$name,body:$body,draft:false,prerelease:false}' |
        curl -fsS "${AUTH[@]}" -H "Content-Type: application/json" -d @- "$API/releases")
    UPLOAD_URL=$(printf '%s' "$RELEASE" | jq -r '.upload_url' | sed 's/{.*//')
    ASSETS_URL=$(printf '%s' "$RELEASE" | jq -r '.assets_url')
fi

ASSET_ID=$(curl -fsS "${AUTH[@]}" "$ASSETS_URL" |
    jq -r --arg name "$ASSET_NAME" '.[] | select(.name == $name) | .id' |
    head -n 1)
if [ -n "$ASSET_ID" ]; then
    curl -fsS -X DELETE "${AUTH[@]}" "$API/releases/assets/$ASSET_ID" >/dev/null
fi

ENCODED_NAME=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$ASSET_NAME")
UPLOAD=$(curl -fsS "${AUTH[@]}" \
    -H "Content-Type: application/x-apple-diskimage" \
    --data-binary "@$DMG" \
    "$UPLOAD_URL?name=$ENCODED_NAME")

printf '%s\n' "$UPLOAD" | jq -r '.browser_download_url'
