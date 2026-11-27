#!/usr/bin/env bash
# Builds a universal Cronbar.app and zips it to dist/Cronbar.zip.
# Usage: scripts/build-app.sh [version]
set -euo pipefail

version=${1:-0.0.0}
version=${version#v}
root="$(cd "$(dirname "$0")/.." && pwd)"
dist="$root/dist"
app="$dist/Cronbar.app"

cd "$root"
swift build -c release --arch arm64 --arch x86_64
bin_path="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

rm -rf "$dist"
mkdir -p "$app/Contents/MacOS"
cp "$bin_path/Cronbar" "$app/Contents/MacOS/Cronbar"

cat >"$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key><string>Cronbar</string>
	<key>CFBundleIdentifier</key><string>io.github.fullchee.cronbar</string>
	<key>CFBundleName</key><string>Cronbar</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>$version</string>
	<key>CFBundleVersion</key><string>$version</string>
	<key>LSMinimumSystemVersion</key><string>14.0</string>
	<key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

# Ad-hoc signature: no Developer ID, but Apple silicon refuses to run unsigned code.
codesign --force --sign - --timestamp=none "$app"

ditto -c -k --keepParent "$app" "$dist/Cronbar.zip"
echo "$dist/Cronbar.zip"
