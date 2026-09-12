#!/bin/bash
# Development keeps a stable certificate; unnotarized packaging is explicitly ad-hoc.
resolve_signing_identity() {
    local mode identities candidates count requested
    mode="$1"
    identities="$2"
    requested="${3:-}"
    case "$mode" in
        unnotarized)
            if [ -n "$requested" ] && [ "$requested" != - ]; then
                echo "Unnotarized packages must not embed a personal signing certificate." >&2
                return 1
            fi
            LIDFOLD_SELECTED_IDENTITY=-
            return 0 ;;
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
    if [ "${LIDFOLD_BUILD_MODE:-development}" = unnotarized ]; then
        resolve_signing_identity unnotarized "" "${LIDFOLD_SIGNING_IDENTITY:-}"
        return
    fi
    identities="$(/usr/bin/security find-identity -v -p codesigning)" || return
    resolve_signing_identity "${LIDFOLD_BUILD_MODE:-development}" "$identities" "${LIDFOLD_SIGNING_IDENTITY:-}"
}
