#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/module-cache dist
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
swift build -c release --disable-sandbox
APP="$PWD/dist/LidFold.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/LidFold "$APP/Contents/MacOS/LidFold"
# The app resolves resources from Contents/Resources; SwiftPM tests use Bundle.module.
rm -rf "$APP/Contents/MacOS/LidFold_LidFoldKit.bundle"
cp Sources/LidFoldKit/Fold.metal "$APP/Contents/Resources/Fold.metal"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>LidFold</string>
<key>CFBundleDisplayName</key><string>LidFold</string>
<key>CFBundleIdentifier</key><string>local.leon.LidFold</string>
<key>CFBundleExecutable</key><string>LidFold</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
plutil -lint "$APP/Contents/Info.plist"
echo "Built: $APP"
