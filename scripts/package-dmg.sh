#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
VERSION=$(plutil -extract version raw -o - version.json)
APP='dist/Mac Usage.app'
test -d "$APP"
STAGING_DIR=$(mktemp -d "${TMPDIR:-/tmp}/mac-usage-dmg.XXXXXX")
trap 'rm -rf "$STAGING_DIR"' EXIT HUP INT TERM
ditto "$APP" "$STAGING_DIR/Mac Usage.app"
ln -s /Applications "$STAGING_DIR/Applications"
hdiutil create -volname 'Mac Usage' -srcfolder "$STAGING_DIR" -ov -format UDZO "dist/mac-usage-$VERSION-universal.dmg"
