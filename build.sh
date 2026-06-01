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

clang -fobjc-arc -o "$APP/Contents/MacOS/$EXEC" \
    main.m AppDelegate.m \
    -framework Cocoa -framework ApplicationServices -framework Carbon -framework Vision

# Sign with a stable self-signed identity if present, so macOS keeps the
# Accessibility/Screen Recording grants across rebuilds (the designated
# requirement pins the bundle id + this cert). Falls back to ad-hoc.
SIGN_ID="Ctrl+Brain Dev"
if security find-identity -p codesigning 2>/dev/null | grep -q "$SIGN_ID"; then
    codesign --force --deep --sign "$SIGN_ID" "$APP" >/dev/null 2>&1 && echo "Signed ($SIGN_ID)."
else
    codesign --force --deep --sign - "$APP" >/dev/null 2>&1 && echo "Signed (ad-hoc)."
fi

echo "Built $APP"
echo "Run it with: open \"$APP\""
echo "First run: grant Accessibility + Screen Recording in System Settings > Privacy & Security."
