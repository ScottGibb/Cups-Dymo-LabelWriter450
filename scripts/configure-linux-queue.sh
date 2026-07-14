#!/bin/sh

set -eu

LC_ALL=C
export LC_ALL

# Usage: configure-linux-queue.sh [local-queue-name] [expected-pi-ipp-uri]
# DYMO_IPP_URI can provide the expected URI when the second argument is omitted.
QUEUE_NAME="${1:-DYMO_LabelWriter_450}"
EXPECTED_IPP_URI="${2:-${DYMO_IPP_URI:-}}"

case "$QUEUE_NAME" in
    '' | *[!A-Za-z0-9_.-]*)
        echo "Queue name may contain only letters, numbers, dots, underscores, and hyphens." >&2
        exit 64
        ;;
esac

if [ "$(uname -s)" != "Linux" ]; then
    echo "This helper must be run on the Linux computer that owns the local printer queue." >&2
    exit 69
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this helper with sudo so it can update the local CUPS queue." >&2
    exit 77
fi

for command_name in cp cupsaccept cupsreject grep lpadmin lpstat mktemp rm sed; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Required command not found: $command_name" >&2
        exit 69
    fi
done

if ! lpstat -h localhost -r 2>/dev/null | grep -q 'scheduler is running'; then
    echo "The local CUPS scheduler is not running." >&2
    exit 69
fi

if ! lpstat -h localhost -p "$QUEUE_NAME" >/dev/null 2>&1; then
    echo "Local CUPS queue not found: $QUEUE_NAME" >&2
    echo "Run 'lpstat -h localhost -p' to list persistent local queues." >&2
    exit 66
fi

QUEUE_LINE="$(lpstat -h localhost -v "$QUEUE_NAME")"
QUEUE_URI="${QUEUE_LINE#*: }"

if [ "$QUEUE_URI" = "$QUEUE_LINE" ]; then
    echo "Unable to read the device URI for $QUEUE_NAME." >&2
    exit 65
fi

case "$QUEUE_URI" in
    ipp://* | ipps://* | dnssd://*)
        ;;
    *)
        echo "Queue $QUEUE_NAME is not an explicit IPP network queue: $QUEUE_URI" >&2
        echo "Create a persistent queue for the Pi; do not use USB, Generic, Everywhere, or implicitclass." >&2
        exit 65
        ;;
esac

if [ -n "$EXPECTED_IPP_URI" ]; then
    case "$EXPECTED_IPP_URI" in
        ipp://* | ipps://* | dnssd://*)
            ;;
        *)
            echo "Expected printer URI must use ipp://, ipps://, or dnssd://." >&2
            exit 64
            ;;
    esac

    if [ "$QUEUE_URI" != "$EXPECTED_IPP_URI" ]; then
        echo "Queue $QUEUE_NAME points to $QUEUE_URI, not $EXPECTED_IPP_URI." >&2
        echo "Recreate or update the queue with the intended Raspberry Pi URI before continuing." >&2
        exit 65
    fi
fi

if [ -n "$(lpstat -h localhost -o "$QUEUE_NAME")" ]; then
    echo "Queue $QUEUE_NAME still has jobs. Cancel or finish them before changing its driver." >&2
    echo "To cancel them: cancel -h localhost -a $QUEUE_NAME" >&2
    exit 75
fi

if command -v cups-config >/dev/null 2>&1; then
    CUPS_SERVER_ROOT="$(cups-config --serverroot)"
    CUPS_SERVER_BIN="$(cups-config --serverbin)"
else
    CUPS_SERVER_ROOT="/etc/cups"
    CUPS_SERVER_BIN=""
fi

QUEUE_PPD="${CUPS_SERVER_ROOT}/ppd/${QUEUE_NAME}.ppd"

if [ ! -r "$QUEUE_PPD" ]; then
    echo "Queue PPD is missing or unreadable: $QUEUE_PPD" >&2
    echo "Add the queue with the DYMO LabelWriter 450 driver first." >&2
    exit 66
fi

if ! grep -Eq '^\*ModelName:[[:space:]]*"DYMO LabelWriter 450"[[:space:]]*$' "$QUEUE_PPD"; then
    echo "Queue $QUEUE_NAME is not using the DYMO LabelWriter 450 driver." >&2
    exit 65
fi

if ! grep -Eq '^\*PageSize[[:space:]]+[^/]+/30256 Shipping:' "$QUEUE_PPD"; then
    echo "Queue $QUEUE_NAME does not contain the expected named DYMO label stocks." >&2
    exit 65
fi

SAFE_FILTER='^\*cupsFilter2:[[:space:]]*"application/vnd\.cups-raster[[:space:]]+application/vnd\.cups-raw[[:space:]]+[0-9]+[[:space:]]+[^"[:space:]]*raster2dymolw"[[:space:]]*$'
LEGACY_FILTER='^\*cupsFilter:[[:space:]]*"application/vnd\.cups-raster[[:space:]]+[0-9]+[[:space:]]+[^"[:space:]]*raster2dymolw"[[:space:]]*$'
FILTER_COUNT="$(grep -Ec '^\*cupsFilter2?[[:space:]]*:' "$QUEUE_PPD" || true)"
SAFE_FILTER_COUNT="$(grep -Ec "$SAFE_FILTER" "$QUEUE_PPD" || true)"

FILTER_PROGRAM="$(
    grep -E "$SAFE_FILTER|$LEGACY_FILTER" "$QUEUE_PPD" \
        | sed -E 's|^.*[[:space:]]+([^"[:space:]]*raster2dymolw)"[[:space:]]*$|\1|' \
        | sed -n '1p'
)"

FILTER_PATH=""
case "$FILTER_PROGRAM" in
    /*)
        FILTER_PATH="$FILTER_PROGRAM"
        ;;
    '')
        ;;
    *)
        if [ -n "$CUPS_SERVER_BIN" ] && [ -x "${CUPS_SERVER_BIN}/filter/${FILTER_PROGRAM}" ]; then
            FILTER_PATH="${CUPS_SERVER_BIN}/filter/${FILTER_PROGRAM}"
        else
            for filter_directory in /usr/lib/cups/filter /usr/libexec/cups/filter /usr/lib64/cups/filter; do
                if [ -x "${filter_directory}/${FILTER_PROGRAM}" ]; then
                    FILTER_PATH="${filter_directory}/${FILTER_PROGRAM}"
                    break
                fi
            done
        fi
        ;;
esac

if [ -z "$FILTER_PATH" ] || [ ! -x "$FILTER_PATH" ]; then
    echo "The DYMO raster filter from $QUEUE_PPD is missing or not executable: $FILTER_PROGRAM" >&2
    exit 69
fi

if [ "$FILTER_COUNT" -eq 1 ] && [ "$SAFE_FILTER_COUNT" -eq 1 ]; then
    if ! lpadmin -h localhost -p "$QUEUE_NAME" -o printer-is-shared=false; then
        echo "Unable to keep the client queue private." >&2
        exit 77
    fi

    echo "Queue $QUEUE_NAME is already configured for network-safe raw output."
    if [ -n "$EXPECTED_IPP_URI" ]; then
        echo "Verified the Raspberry Pi queue URI: $EXPECTED_IPP_URI"
    fi
    exit 0
fi

LEGACY_FILTER_COUNT="$(grep -Ec "$LEGACY_FILTER" "$QUEUE_PPD" || true)"

if [ "$FILTER_COUNT" -ne 1 ] || [ "$LEGACY_FILTER_COUNT" -ne 1 ]; then
    echo "Expected one legacy DYMO raster filter in $QUEUE_PPD." >&2
    echo "Found $FILTER_COUNT total filter declarations and $LEGACY_FILTER_COUNT matching legacy declarations." >&2
    echo "The queue was not changed." >&2
    exit 65
fi

umask 077
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dymo-linux-queue.XXXXXX")"
ORIGINAL_PPD="${TEMP_DIR}/original.ppd"
NETWORK_PPD="${TEMP_DIR}/network.ppd"
QUEUE_REJECTED_BY_HELPER=0
QUEUE_WAS_ACCEPTING=0
QUEUE_CONFIGURATION_SAFE=1

restore_acceptance() {
    if [ "$QUEUE_REJECTED_BY_HELPER" -ne 1 ]; then
        return 0
    fi

    if [ "$QUEUE_WAS_ACCEPTING" -eq 1 ]; then
        if [ "$QUEUE_CONFIGURATION_SAFE" -ne 1 ]; then
            cupsreject \
                -h localhost \
                -r 'PPD verification failed; restore the DYMO driver before accepting jobs' \
                "$QUEUE_NAME" >/dev/null 2>&1 || true
            echo "Leaving $QUEUE_NAME rejected because its PPD could not be verified after the attempted change." >&2
            return 1
        fi

        if ! cupsaccept -h localhost "$QUEUE_NAME"; then
            echo "Unable to restore $QUEUE_NAME to its previous accepting state." >&2
            return 1
        fi
    fi

    QUEUE_REJECTED_BY_HELPER=0
    return 0
}

cleanup() {
    exit_status=$?
    trap - EXIT HUP INT TERM

    if ! restore_acceptance; then
        if [ "$exit_status" -eq 0 ]; then
            exit_status=78
        fi
    fi

    rm -rf "$TEMP_DIR"
    exit "$exit_status"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

cp "$QUEUE_PPD" "$ORIGINAL_PPD"

sed -E \
    's|^\*cupsFilter:[[:space:]]*"application/vnd\.cups-raster[[:space:]]+([0-9]+)[[:space:]]+([^"[:space:]]*raster2dymolw)"[[:space:]]*$|*cupsFilter2: "application/vnd.cups-raster application/vnd.cups-raw \1 \2"|' \
    "$ORIGINAL_PPD" >"$NETWORK_PPD"

if [ "$(grep -Ec "$SAFE_FILTER" "$NETWORK_PPD" || true)" -ne 1 ]; then
    echo "Unable to create the network-safe PPD; the queue was not changed." >&2
    exit 65
fi

restore_original() {
    if ! lpadmin -h localhost -p "$QUEUE_NAME" -P "$ORIGINAL_PPD" -o printer-is-shared=false; then
        echo "Automatic rollback failed. Restore $QUEUE_NAME with its DYMO driver before printing." >&2
        return 1
    fi

    restored_filter_count="$(grep -Ec '^\*cupsFilter2?[[:space:]]*:' "$QUEUE_PPD" || true)"
    restored_legacy_count="$(grep -Ec "$LEGACY_FILTER" "$QUEUE_PPD" || true)"
    if [ "$restored_filter_count" -ne 1 ] || [ "$restored_legacy_count" -ne 1 ]; then
        echo "CUPS accepted the rollback but did not restore the original DYMO filter." >&2
        return 1
    fi

    QUEUE_CONFIGURATION_SAFE=1
    echo "Restored the original PPD for $QUEUE_NAME." >&2
    return 0
}

ACCEPTANCE_LINE="$(lpstat -h localhost -a "$QUEUE_NAME")"
case "$ACCEPTANCE_LINE" in
    "$QUEUE_NAME accepting requests"*)
        QUEUE_WAS_ACCEPTING=1
        ;;
    "$QUEUE_NAME not accepting requests"*)
        QUEUE_WAS_ACCEPTING=0
        ;;
    *)
        echo "Unable to determine whether $QUEUE_NAME is accepting jobs; the PPD was not changed." >&2
        exit 69
        ;;
esac

if [ "$QUEUE_WAS_ACCEPTING" -eq 1 ]; then
    QUEUE_REJECTED_BY_HELPER=1
    if ! cupsreject -h localhost -r 'Temporarily paused by configure-linux-queue.sh' "$QUEUE_NAME"; then
        echo "Unable to stop $QUEUE_NAME from accepting new jobs; the PPD was not changed." >&2
        exit 77
    fi
fi

if [ -n "$(lpstat -h localhost -o "$QUEUE_NAME")" ]; then
    echo "Queue $QUEUE_NAME received a job during setup; the PPD was not changed." >&2
    exit 75
fi

QUEUE_CONFIGURATION_SAFE=0
if ! lpadmin -h localhost -p "$QUEUE_NAME" -P "$NETWORK_PPD" -o printer-is-shared=false; then
    echo "CUPS rejected the network-safe PPD; restoring the original." >&2
    restore_original || true
    exit 77
fi

if [ "$(grep -Ec "$SAFE_FILTER" "$QUEUE_PPD" || true)" -ne 1 ]; then
    echo "CUPS did not retain the network-safe filter declaration; restoring the original." >&2
    restore_original || true
    exit 70
fi

QUEUE_CONFIGURATION_SAFE=1
if ! restore_acceptance; then
    exit 78
fi

echo "Configured $QUEUE_NAME to send DYMO-ready data as application/vnd.cups-raw."
if [ -n "$EXPECTED_IPP_URI" ]; then
    echo "Verified the Raspberry Pi queue URI: $EXPECTED_IPP_URI"
fi
echo "Kept the client queue private to avoid advertising a second forwarding queue."
echo "No print job was submitted."
