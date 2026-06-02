#!/bin/bash
# Builds, Developer ID signs, packages, signs, and optionally notarizes a DMG.
set -euo pipefail

APP="Ctrl+Brain.app"
VOLNAME="Ctrl+Brain"
DMG_NAME="Ctrl+Brain-1.0.dmg"
STAGING_DIR="dist/dmg-staging"
OUTPUT_DIR="dist"

cleanup() {
    rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

find_developer_id() {
    security find-identity -v -p codesigning |
        sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' |
        head -n 1
}

SIGN_IDENTITY="${SIGN_IDENTITY:-$(find_developer_id)}"
if [ -z "$SIGN_IDENTITY" ]; then
    echo "error: no Developer ID Application signing identity found in the keychain." >&2
    echo "Install your Apple Developer ID Application certificate, then rerun this script." >&2
    exit 1
fi

APPLE_SIGNING=1 SIGN_IDENTITY="$SIGN_IDENTITY" ./build.sh

codesign --verify --strict --deep --verbose=2 "$APP"
if ! spctl --assess --type execute --verbose=4 "$APP"; then
    echo "warning: app is signed but Gatekeeper will reject it until notarization is stapled." >&2
fi

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR" "$OUTPUT_DIR"
cp -R "$APP" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$OUTPUT_DIR/$DMG_NAME"
hdiutil create \
    -volname "$VOLNAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$OUTPUT_DIR/$DMG_NAME"

codesign --force --sign "$SIGN_IDENTITY" --timestamp "$OUTPUT_DIR/$DMG_NAME"
codesign --verify --verbose=2 "$OUTPUT_DIR/$DMG_NAME"

if [ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]; then
    xcrun notarytool submit "$OUTPUT_DIR/$DMG_NAME" \
        --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
        --wait
    xcrun stapler staple "$OUTPUT_DIR/$DMG_NAME"
elif [ -n "${APPLE_ID:-}" ] && [ -n "${APPLE_TEAM_ID:-}" ] && [ -n "${APPLE_APP_PASSWORD:-}" ]; then
    xcrun notarytool submit "$OUTPUT_DIR/$DMG_NAME" \
        --apple-id "$APPLE_ID" \
        --team-id "$APPLE_TEAM_ID" \
        --password "$APPLE_APP_PASSWORD" \
        --wait
    xcrun stapler staple "$OUTPUT_DIR/$DMG_NAME"
else
    echo "warning: DMG is signed but not notarized." >&2
    echo "Set NOTARY_KEYCHAIN_PROFILE, or APPLE_ID + APPLE_TEAM_ID + APPLE_APP_PASSWORD, to notarize." >&2
fi

if ! spctl --assess --type open --context context:primary-signature --verbose=4 "$OUTPUT_DIR/$DMG_NAME"; then
    echo "warning: DMG signature exists, but Gatekeeper acceptance requires notarization." >&2
fi
cleanup
echo "Created $OUTPUT_DIR/$DMG_NAME"
