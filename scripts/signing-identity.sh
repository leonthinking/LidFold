#!/bin/bash
# Source this file; the chosen identity is a certificate hash, never an ad-hoc DR.
resolve_signing_identity() {
    local mode identities candidates count requested
    mode="$1"
    identities="$2"
    requested="${3:-}"
    case "$mode" in
        development) candidates="$(printf '%s\n' "$identities" | /usr/bin/awk '/"Apple Development:|"Developer ID Application:/ {print $2}')" ;;
        distribution) candidates="$(printf '%s\n' "$identities" | /usr/bin/awk '/"Developer ID Application:/ {print $2}')" ;;
        *) echo "Unknown build mode: $mode" >&2; return 1 ;;
    esac
    if [ -n "$requested" ]; then
        candidates="$(printf '%s\n' "$candidates" | /usr/bin/awk -v wanted="$requested" '$0 == wanted')"
    fi
    count="$(printf '%s\n' "$candidates" | /usr/bin/awk 'NF {n++} END {print n+0}')"
    if [ "$count" -ne 1 ]; then
        echo "Expected one valid identity for mode $mode. Distribution requires Developer ID Application; use LIDFOLD_SIGNING_IDENTITY to select its SHA-1." >&2
        echo "Ad-hoc signing is disabled to preserve screen recording authorization." >&2
        return 1
    fi
    LIDFOLD_SELECTED_IDENTITY="$candidates"
}

select_signing_identity() {
    local identities
    identities="$(/usr/bin/security find-identity -v -p codesigning)" || return
    resolve_signing_identity "${LIDFOLD_BUILD_MODE:-development}" "$identities" "${LIDFOLD_SIGNING_IDENTITY:-}"
}
