#!/bin/bash
# Builds Ctrl+Brain from the command line, without an Xcode project.
set -euo pipefail

APP="Ctrl+Brain.app"
EXEC="CtrlBrain"
rm -rf "$APP" "SecondBrainCapture.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"

# Bundle the .env so the GUI app can read the key without a shell environment.
if [ -f .env ]; then
    cp .env "$APP/Contents/Resources/.env"
fi

# Bundle the logo for the menu-bar icon.
if [ -f assets/logo.svg ]; then
    cp assets/logo.svg "$APP/Contents/Resources/logo.svg"
fi

# Bundle the app icon (Finder / Get Info).
if [ -f assets/AppIcon.icns ]; then
    cp assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

# Bundle the web fonts (Instrument Serif + Space Grotesk) so the app matches the site.
if [ -d assets/fonts ]; then
    mkdir -p "$APP/Contents/Resources/fonts"
    cp assets/fonts/*.ttf "$APP/Contents/Resources/fonts/" 2>/dev/null || true
fi

clang -fobjc-arc -o "$APP/Contents/MacOS/$EXEC" \
    main.m AppDelegate.m \
    -framework Cocoa -framework QuartzCore -framework ApplicationServices -framework Carbon -framework Vision -framework AuthenticationServices

# Sign with an explicit identity when provided. Otherwise use the stable
# self-signed dev identity if present so macOS keeps permission grants across
# rebuilds. Falls back to ad-hoc for local development only.
SIGN_ID="${SIGN_IDENTITY:-Ctrl+Brain Dev}"
if security find-identity -p codesigning 2>/dev/null | grep -q "$SIGN_ID"; then
    CODESIGN_ARGS=(--force --deep --sign "$SIGN_ID")
    if [ "${APPLE_SIGNING:-0}" = "1" ]; then
        CODESIGN_ARGS+=(--options runtime --timestamp)
    fi
    codesign "${CODESIGN_ARGS[@]}" "$APP" >/dev/null 2>&1 && echo "Signed ($SIGN_ID)."
else
    if [ -n "${SIGN_IDENTITY:-}" ]; then
        echo "error: requested signing identity was not found: $SIGN_IDENTITY" >&2
        exit 1
    fi
    codesign --force --deep --sign - "$APP" >/dev/null 2>&1 && echo "Signed (ad-hoc)."
fi

echo "Built $APP"
echo "Run it with: open \"$APP\""
echo "First run: grant Accessibility + Screen Recording in System Settings > Privacy & Security."
