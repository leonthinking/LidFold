#!/bin/bash
# Source this file; the chosen identity is a certificate hash, never an ad-hoc DR.
select_signing_identity() {
    local identities candidates count requested
    identities="$(/usr/bin/security find-identity -v -p codesigning)"
    requested="${LIDFOLD_SIGNING_IDENTITY:-}"
    if [ -n "$requested" ]; then
        candidates="$(printf '%s\n' "$identities" | /usr/bin/awk -v wanted="$requested" '$2 == wanted {print $2}')"
    else
        candidates="$(printf '%s\n' "$identities" | /usr/bin/awk '/"Apple Development:|"Developer ID Application:/ {print $2}')"
    fi
    count="$(printf '%s\n' "$candidates" | /usr/bin/awk 'NF {n++} END {print n+0}')"
    if [ "$count" -ne 1 ]; then
        echo "需要唯一且有效的签名证书。请将 LIDFOLD_SIGNING_IDENTITY 设为 security find-identity -v -p codesigning 列出的证书 SHA-1。" >&2
        echo "不会回退到临时签名，以免再次破坏屏幕录制授权。" >&2
        return 1
    fi
    LIDFOLD_SELECTED_IDENTITY="$candidates"
}
