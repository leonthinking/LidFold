#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/signing-identity.sh
select_signing_identity
ensure_not_running() {
    local status=0
    /usr/bin/pgrep -x LidFold >/dev/null || status=$?
    if [ "$status" -eq 0 ]; then
        echo "请先退出 LidFold，再替换应用；运行中的签名应用不能原地重写。" >&2
        exit 1
    elif [ "$status" -ne 1 ]; then
        echo "无法检查运行中的应用，请在可访问本机进程的终端中构建。" >&2
        exit 1
    fi
}
ensure_not_running
mkdir -p .build/module-cache dist
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
swift build -c release --disable-sandbox
STAGING="$(mktemp -d "$PWD/.build/app-staging.XXXXXX")"
APP="$STAGING/LidFold.app"
DESTINATION="$PWD/dist/LidFold.app"
cleanup() {
    if [ -d "$STAGING/Previous.app" ] && [ ! -e "$DESTINATION" ]; then
        mv "$STAGING/Previous.app" "$DESTINATION"
    fi
    rm -rf "$STAGING"
}
trap cleanup EXIT
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
<key>CFBundleShortVersionString</key><string>0.1.1</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign "$LIDFOLD_SELECTED_IDENTITY" --timestamp=none "$APP"
codesign --verify --deep --strict "$APP"
plutil -lint "$APP/Contents/Info.plist"
ensure_not_running
if [ -d "$DESTINATION" ]; then mv "$DESTINATION" "$STAGING/Previous.app"; fi
mv "$APP" "$DESTINATION"
echo "Built: $DESTINATION"
