#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
swift build --build-system native -c release
BIN_DIR=$(swift build --build-system native -c release --show-bin-path)
APP="dist/Mac Usage.app"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN_DIR/MacUsageTracker" "$APP/Contents/MacOS/MacUsageTracker"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.jeremiah.macusage</string>
<key>CFBundleName</key><string>Mac Usage</string>
<key>CFBundleDisplayName</key><string>Mac Usage</string>
<key>CFBundleExecutable</key><string>MacUsageTracker</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
printf 'Built %s\n' "$APP"
