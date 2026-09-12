#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export LIDFOLD_BUILD_MODE=distribution
. scripts/signing-identity.sh
# Fail before building or changing any App when no distribution identity exists.
select_signing_identity
: "${LIDFOLD_NOTARY_PROFILE:?Set LIDFOLD_NOTARY_PROFILE to a local notarytool Keychain profile}"
xcrun --find notarytool >/dev/null
xcrun --find stapler >/dev/null
mkdir -p .build dist/releases
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
bash scripts/build-app.sh
WORK="$(mktemp -d "$PWD/.build/notary.XXXXXX")"
# Notarize an isolated snapshot, not a build destination that can be replaced.
ditto "$PWD/dist/distribution/LidFold.app" "$WORK/LidFold.app"
APP="$WORK/LidFold.app"
VERSION="$(python3 scripts/release_support.py version "$APP/Contents/Info.plist")"
FINAL="$PWD/dist/releases/$VERSION"
if [ -e "$FINAL" ]; then
    echo "Release directory already exists; choose a new version rather than overwrite it." >&2
    exit 1
fi
codesign --verify --deep --strict "$APP"
"$APP/Contents/MacOS/LidFold" --self-check
ditto -c -k --keepParent "$APP" "$WORK/submission.zip"
xcrun notarytool submit "$WORK/submission.zip" --keychain-profile "$LIDFOLD_NOTARY_PROFILE" --wait --output-format json > "$WORK/result.json"
python3 scripts/release_support.py notary-accepted "$WORK/result.json"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"
mkdir "$WORK/publish"
ARCHIVE="LidFold-$VERSION-arm64.zip"
ditto -c -k --keepParent "$APP" "$WORK/publish/$ARCHIVE"
(cd "$WORK/publish" && shasum -a 256 "$ARCHIVE" > SHA256SUMS)
mv "$WORK/publish" "$FINAL"
echo "Verified archive and SHA256SUMS: $FINAL"
