#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
VERSION=$(plutil -extract version raw -o - version.json)
BUILD=$(plutil -extract build raw -o - version.json)
DMG=${1:-dist/mac-usage-$VERSION-universal.dmg}
MOUNT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/mac-usage-mount.XXXXXX")
MOUNTED=0
cleanup() {
  if [ "$MOUNTED" = 1 ]; then hdiutil detach "$MOUNT_DIR" >/dev/null; fi
  rmdir "$MOUNT_DIR"
}
trap cleanup EXIT HUP INT TERM
hdiutil attach -readonly -nobrowse -mountpoint "$MOUNT_DIR" "$DMG" >/dev/null
MOUNTED=1
APP="$MOUNT_DIR/Mac Usage.app"
test -d "$APP"
test "$(readlink "$MOUNT_DIR/Applications")" = /Applications
codesign --verify --strict "$APP"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")" = "$VERSION"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")" = "$BUILD"
lipo "$APP/Contents/MacOS/MacUsageTracker" -verify_arch arm64
lipo "$APP/Contents/MacOS/MacUsageTracker" -verify_arch x86_64
printf 'Verified installer layout and version %s (%s)\n' "$VERSION" "$BUILD"
