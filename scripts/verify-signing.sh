#!/bin/bash
# Regression: changing app content must change CDHash but preserve code identity.
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/signing-identity.sh
select_signing_identity
APP="$PWD/dist/LidFold.app"
TEST_ROOT="$(mktemp -d "$PWD/.build/signing-test.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT
codesign --verify --deep --strict "$APP"
codesign -d -r- "$APP" > "$TEST_ROOT/original.txt" 2>&1
sed -n 's/^designated => //p' "$TEST_ROOT/original.txt" > "$TEST_ROOT/identity.req"
if ! grep -q 'certificate' "$TEST_ROOT/identity.req" || grep -q 'cdhash' "$TEST_ROOT/identity.req"; then
    echo "FAIL: application identity is not certificate based" >&2
    exit 1
fi
cp -R "$APP" "$TEST_ROOT/LidFold.app"
printf '\n// Signing regression fixture\n' >> "$TEST_ROOT/LidFold.app/Contents/Resources/Fold.metal"
codesign --force --sign "$LIDFOLD_SELECTED_IDENTITY" --timestamp=none "$TEST_ROOT/LidFold.app"
codesign --verify --strict -R "$TEST_ROOT/identity.req" "$TEST_ROOT/LidFold.app"
codesign -d -r- "$TEST_ROOT/LidFold.app" > "$TEST_ROOT/updated.txt" 2>&1
sed -n 's/^designated => //p' "$TEST_ROOT/updated.txt" > "$TEST_ROOT/updated.req"
cmp "$TEST_ROOT/identity.req" "$TEST_ROOT/updated.req"
original_hash="$(codesign -dvvv "$APP" 2>&1 | sed -n 's/^CDHash=//p')"
updated_hash="$(codesign -dvvv "$TEST_ROOT/LidFold.app" 2>&1 | sed -n 's/^CDHash=//p')"
test -n "$original_hash"
test -n "$updated_hash"
test "$original_hash" != "$updated_hash"
echo "PASS: changed content has a different hash and satisfies the original certificate identity"
