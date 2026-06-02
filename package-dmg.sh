#!/bin/bash
# Builds, Developer ID signs, packages, signs, and optionally notarizes a DMG.
set -euo pipefail

APP="Ctrl+Brain.app"
VOLNAME="Ctrl+Brain"
DMG_NAME="Ctrl+Brain-1.0.dmg"
STAGING_DIR="dist/dmg-staging"
OUTPUT_DIR="dist"
TEMP_DMG="$OUTPUT_DIR/Ctrl+Brain-1.0.temp.dmg"
MOUNT_DIR="/Volumes/$VOLNAME"

cleanup() {
    rm -rf "$STAGING_DIR"
    hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true
    rm -f "$TEMP_DMG"
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
mkdir -p "$STAGING_DIR/.background" "$OUTPUT_DIR"
cp -R "$APP" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
swift - "$STAGING_DIR/.background/background.png" <<'SWIFT'
import AppKit

let output = CommandLine.arguments[1]
let size = NSSize(width: 680, height: 380)
let image = NSImage(size: size)

image.lockFocus()

let rect = NSRect(origin: .zero, size: size)
NSGradient(colors: [
    NSColor(calibratedRed: 0.965, green: 0.960, blue: 0.930, alpha: 1.0),
    NSColor(calibratedRed: 0.890, green: 0.880, blue: 0.830, alpha: 1.0)
])!.draw(in: rect, angle: -20)

NSColor(calibratedWhite: 0.42, alpha: 0.22).setStroke()
for offset in stride(from: -160.0, through: 720.0, by: 160.0) {
    let line = NSBezierPath()
    line.move(to: NSPoint(x: offset, y: 0))
    line.line(to: NSPoint(x: offset + 210, y: size.height))
    line.lineWidth = 1
    line.stroke()
}
for offset in stride(from: -80.0, through: 760.0, by: 220.0) {
    let curve = NSBezierPath()
    curve.move(to: NSPoint(x: offset, y: 42))
    curve.curve(to: NSPoint(x: offset + 250, y: 125),
                controlPoint1: NSPoint(x: offset + 72, y: 92),
                controlPoint2: NSPoint(x: offset + 168, y: 100))
    curve.lineWidth = 1
    curve.stroke()
}

let title = "To install, drag Ctrl+Brain\nto Applications"
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont(name: "Georgia", size: 36) ?? NSFont.systemFont(ofSize: 36, weight: .regular),
    .foregroundColor: NSColor(calibratedWhite: 0.24, alpha: 1.0)
]
title.draw(in: NSRect(x: 0, y: 266, width: size.width, height: 88), withAttributes: titleAttrs.merging([.paragraphStyle: {
    let p = NSMutableParagraphStyle()
    p.alignment = .center
    p.lineHeightMultiple = 0.92
    return p
}()]) { $1 })

let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 292, y: 214))
arrow.curve(to: NSPoint(x: 430, y: 204),
            controlPoint1: NSPoint(x: 320, y: 255),
            controlPoint2: NSPoint(x: 390, y: 246))
arrow.lineWidth = 5
NSColor(calibratedWhite: 0.30, alpha: 0.78).setStroke()
arrow.stroke()

let head = NSBezierPath()
head.move(to: NSPoint(x: 430, y: 204))
head.line(to: NSPoint(x: 392, y: 222))
head.move(to: NSPoint(x: 430, y: 204))
head.line(to: NSPoint(x: 398, y: 180))
head.lineWidth = 5
head.stroke()

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let rep = NSBitmapImageRep(data: tiff),
    let png = rep.representation(using: .png, properties: [:])
else {
    fatalError("failed to render DMG background")
}
try png.write(to: URL(fileURLWithPath: output))
SWIFT

rm -f "$OUTPUT_DIR/$DMG_NAME" "$TEMP_DMG"
hdiutil create \
    -volname "$VOLNAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDRW \
    "$TEMP_DMG"

hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true
hdiutil attach -readwrite -noverify -noautoopen -mountpoint "$MOUNT_DIR" "$TEMP_DMG" >/dev/null

osascript <<'APPLESCRIPT'
tell application "Finder"
    tell disk "Ctrl+Brain"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {160, 100, 840, 480}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 128
        set text size of theViewOptions to 14
        set background picture of theViewOptions to POSIX file "/Volumes/Ctrl+Brain/.background/background.png"
        set position of item "Ctrl+Brain.app" of container window to {175, 225}
        set position of item "Applications" of container window to {515, 225}
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$MOUNT_DIR" >/dev/null
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$OUTPUT_DIR/$DMG_NAME" >/dev/null

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
