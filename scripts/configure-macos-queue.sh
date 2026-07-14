#!/bin/sh

set -eu

QUEUE_NAME="${1:-DYMO_LabelWriter_450}"

case "$QUEUE_NAME" in
    '' | *[!A-Za-z0-9_.-]*)
        echo "Queue name may contain only letters, numbers, dots, underscores, and hyphens." >&2
        exit 64
        ;;
esac

if [ "$(uname -s)" != "Darwin" ]; then
    echo "This helper must be run on the Mac that owns the local printer queue." >&2
    exit 69
fi

for command_name in grep lpadmin lpstat mktemp sed; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Required command not found: $command_name" >&2
        exit 69
    fi
done

if ! lpstat -p "$QUEUE_NAME" >/dev/null 2>&1; then
    echo "Local CUPS queue not found: $QUEUE_NAME" >&2
    echo "Run 'lpstat -p' to find its queue name." >&2
    exit 66
fi

QUEUE_PPD="/etc/cups/ppd/${QUEUE_NAME}.ppd"

if [ ! -r "$QUEUE_PPD" ]; then
    echo "Queue PPD is missing or unreadable: $QUEUE_PPD" >&2
    echo "Add the queue with the DYMO LabelWriter 450 software first." >&2
    exit 66
fi

if ! grep -q '^\*NickName: "DYMO LabelWriter 450"' "$QUEUE_PPD"; then
    echo "Queue $QUEUE_NAME is not using the DYMO LabelWriter 450 software." >&2
    exit 65
fi

if grep -Eq '^\*cupsFilter2: "application/vnd\.cups-raster application/vnd\.cups-raw 0 [^"]*raster2dymolw"$' "$QUEUE_PPD"; then
    echo "Queue $QUEUE_NAME is already configured for network-safe raw output."
    exit 0
fi

FILTER_COUNT="$(
    grep -Ec '^\*cupsFilter:[[:space:]]*"application/vnd\.cups-raster[[:space:]]+[0-9]+[[:space:]]+[^"]*raster2dymolw"$' \
        "$QUEUE_PPD" || true
)"

if [ "$FILTER_COUNT" -ne 1 ]; then
    echo "Expected one legacy DYMO raster filter in $QUEUE_PPD; found $FILTER_COUNT." >&2
    echo "The queue was not changed." >&2
    exit 65
fi

NETWORK_PPD="$(mktemp "${TMPDIR:-/tmp}/dymo-network-ppd.XXXXXX")"

cleanup() {
    rm -f "$NETWORK_PPD"
}
trap cleanup EXIT HUP INT TERM

sed -E \
    's|^\*cupsFilter:[[:space:]]*"application/vnd\.cups-raster[[:space:]]+[0-9]+[[:space:]]+([^"]*raster2dymolw)"$|*cupsFilter2: "application/vnd.cups-raster application/vnd.cups-raw 0 \1"|' \
    "$QUEUE_PPD" >"$NETWORK_PPD"

if ! grep -Eq '^\*cupsFilter2: "application/vnd\.cups-raster application/vnd\.cups-raw 0 [^"]*raster2dymolw"$' "$NETWORK_PPD"; then
    echo "Unable to create the network-safe PPD; the queue was not changed." >&2
    exit 65
fi

if ! lpadmin -p "$QUEUE_NAME" -P "$NETWORK_PPD"; then
    echo "CUPS rejected the update. Run this helper with sudo and try again." >&2
    exit 77
fi

if ! grep -Eq '^\*cupsFilter2: "application/vnd\.cups-raster application/vnd\.cups-raw 0 [^"]*raster2dymolw"$' "$QUEUE_PPD"; then
    echo "CUPS did not retain the network-safe filter declaration." >&2
    exit 70
fi

echo "Configured $QUEUE_NAME to send DYMO-ready data as application/vnd.cups-raw."
echo "No print job was submitted."
