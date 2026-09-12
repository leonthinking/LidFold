#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/signing-identity.sh
select_signing_identity
BUILD_MODE="${LIDFOLD_BUILD_MODE:-development}"
BUILD_ARGS=(-c release --disable-sandbox)
SIGN_ARGS=(--timestamp=none)
DESTINATION="$PWD/dist/LidFold.app"
if [ "$BUILD_MODE" = distribution ] || [ "$BUILD_MODE" = unnotarized ]; then
    BUILD_ARGS+=(--arch arm64)
    WORK_PREFIX=notary
    if [ "$BUILD_MODE" = distribution ]; then
        SIGN_ARGS=(--options runtime --timestamp)
    else
        WORK_PREFIX=unnotarized
    fi
    DESTINATION="$PWD/dist/$BUILD_MODE/LidFold.app"
    if [ -n "${LIDFOLD_RELEASE_WORKDIR:-}" ]; then
        RELEASE_WORKDIR="$(cd "$LIDFOLD_RELEASE_WORKDIR" && pwd -P)"
        if [ "$(dirname "$RELEASE_WORKDIR")" != "$PWD/.build" ] || [[ "$(basename "$RELEASE_WORKDIR")" != "$WORK_PREFIX".* ]]; then
            echo "Release work directory must be a private .build/$WORK_PREFIX.* directory." >&2
            exit 1
        fi
        DESTINATION="$RELEASE_WORKDIR/LidFold.app"
    fi
fi
mkdir -p .build
BUILD_LOCK="$PWD/.build/build.lock"
if ! mkdir "$BUILD_LOCK" 2>/dev/null; then
    echo "Another App build is active (or left a stale .build/build.lock)." >&2
    exit 1
fi
STAGING=""
cleanup() {
    if [ -n "$STAGING" ]; then
        if [ -d "$STAGING/Previous.app" ] && [ ! -e "$DESTINATION" ]; then
            mv "$STAGING/Previous.app" "$DESTINATION"
        fi
        rm -rf "$STAGING"
    fi
    rmdir "$BUILD_LOCK"
}
trap cleanup EXIT
ensure_not_running() {
    # A private release destination cannot replace the running development App.
    if [ -n "${RELEASE_WORKDIR:-}" ]; then return; fi
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
mkdir -p .build/module-cache "$(dirname "$DESTINATION")"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
swift build "${BUILD_ARGS[@]}"
BIN_PATH="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
STAGING="$(mktemp -d "$PWD/.build/app-staging.XXXXXX")"
APP="$STAGING/LidFold.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH/LidFold" "$APP/Contents/MacOS/LidFold"
# The app resolves resources from Contents/Resources; SwiftPM tests use Bundle.module.
rm -rf "$APP/Contents/MacOS/LidFold_LidFoldKit.bundle"
cp Sources/LidFoldKit/Fold.metal "$APP/Contents/Resources/Fold.metal"
cp LICENSE "$APP/Contents/Resources/LICENSE"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>LidFold</string>
<key>CFBundleDisplayName</key><string>LidFold</string>
<key>CFBundleIdentifier</key><string>local.leon.LidFold</string>
<key>CFBundleExecutable</key><string>LidFold</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.2.4</string>
<key>CFBundleVersion</key><string>7</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign "$LIDFOLD_SELECTED_IDENTITY" "${SIGN_ARGS[@]}" "$APP"
codesign --verify --deep --strict "$APP"
plutil -lint "$APP/Contents/Info.plist"
ensure_not_running
if [ -d "$DESTINATION" ]; then mv "$DESTINATION" "$STAGING/Previous.app"; fi
mv "$APP" "$DESTINATION"
echo "Built: $DESTINATION"
