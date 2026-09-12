#!/bin/bash
# Explicit, certificate-free downloads. This does not satisfy notarized release gates.
set -euo pipefail
cd "$(dirname "$0")/.."
export LIDFOLD_BUILD_MODE=unnotarized
. scripts/signing-identity.sh
select_signing_identity
mkdir -p .build dist/releases-unnotarized
LOCK="$PWD/.build/release.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
    echo "Another release is active (or left a stale .build/release.lock)." >&2
    exit 1
fi
WORK=""
cleanup() {
    if [ -n "$WORK" ]; then rm -rf "$WORK"; fi
    rmdir "$LOCK"
}
trap cleanup EXIT
WORK="$(mktemp -d "$PWD/.build/unnotarized.XXXXXX")"
LIDFOLD_RELEASE_WORKDIR="$WORK" bash scripts/build-app.sh
APP="$WORK/LidFold.app"
VERSION="$(python3 scripts/release_support.py version "$APP/Contents/Info.plist")"
FINAL="$PWD/dist/releases-unnotarized/$VERSION"
if [ -e "$FINAL" ]; then
    echo "Release directory already exists; choose a new version rather than overwrite it." >&2
    exit 1
fi
codesign --verify --deep --strict "$APP"
# Ensure a local developer certificate is never included in a public download.
codesign -dv "$APP" 2> "$WORK/signature.txt"
grep -qx 'Signature=adhoc' "$WORK/signature.txt"
test "$(lipo -archs "$APP/Contents/MacOS/LidFold")" = arm64
"$APP/Contents/MacOS/LidFold" --self-check
mkdir "$WORK/publish" "$WORK/dmg"
NAME="LidFold-$VERSION-arm64-unnotarized"
ditto -c -k --keepParent "$APP" "$WORK/publish/$NAME.zip"
ditto "$APP" "$WORK/dmg/LidFold.app"
ln -s /Applications "$WORK/dmg/Applications"
cp docs/INSTALL.txt "$WORK/dmg/INSTALL.txt"
hdiutil create -volname "LidFold $VERSION" -srcfolder "$WORK/dmg" -format UDZO "$WORK/publish/$NAME.dmg"
hdiutil verify "$WORK/publish/$NAME.dmg"
(cd "$WORK/publish" && shasum -a 256 "$NAME.dmg" "$NAME.zip" > SHA256SUMS)
mv "$WORK/publish" "$FINAL"
echo "Unnotarized DMG, ZIP and SHA256SUMS: $FINAL"
