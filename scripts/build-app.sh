#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
VERSION=$(plutil -extract version raw -o - version.json)
BUILD=$(plutil -extract build raw -o - version.json)
SIGNING_IDENTITY=${MAC_SIGNING_IDENTITY:--}
if [ "${RELEASE_SIGNING_REQUIRED:-0}" = 1 ]; then
  case "$SIGNING_IDENTITY" in
    "Developer ID Application: "*) ;;
    *) printf '%s\n' 'A Developer ID Application identity is required for public releases' >&2; exit 1 ;;
  esac
fi
swift build --build-system native -c release --arch arm64 --arch x86_64
BIN_DIR=$(swift build --build-system native -c release --arch arm64 --arch x86_64 --show-bin-path)
APP="dist/Mac Usage.app"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN_DIR/MacUsageTracker" "$APP/Contents/MacOS/MacUsageTracker"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.jeremiah.macusage</string>
<key>CFBundleName</key><string>Mac Usage</string>
<key>CFBundleDisplayName</key><string>Mac Usage</string>
<key>CFBundleExecutable</key><string>MacUsageTracker</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$BUILD</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
if [ "$SIGNING_IDENTITY" = - ]; then
  codesign --force --sign - "$APP"
else
  codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP"
fi
codesign --verify --strict "$APP"
lipo "$APP/Contents/MacOS/MacUsageTracker" -verify_arch arm64
lipo "$APP/Contents/MacOS/MacUsageTracker" -verify_arch x86_64
printf 'Built %s (%s, build %s)\n' "$APP" "$VERSION" "$BUILD"
