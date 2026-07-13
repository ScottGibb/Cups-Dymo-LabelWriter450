#!/bin/sh

set -eu

PRINTER_NAME="${PRINTER_NAME:-dymo}"
PRINTER_MODEL="${PRINTER_MODEL:-dymo:0/cups/model/lw450.ppd}"
PRINTER_URI="${PRINTER_URI:-}"
DISCOVERY_INTERVAL_SECONDS="${DISCOVERY_INTERVAL_SECONDS:-10}"

case "$DISCOVERY_INTERVAL_SECONDS" in
    *[!0-9]* | '')
        echo "DISCOVERY_INTERVAL_SECONDS must be a positive whole number" >&2
        exit 64
        ;;
esac

if [ "$DISCOVERY_INTERVAL_SECONDS" -eq 0 ]; then
    echo "DISCOVERY_INTERVAL_SECONDS must be greater than zero" >&2
    exit 64
fi

stop_cups() {
    if kill -0 "$CUPSD_PID" 2>/dev/null; then
        kill -TERM "$CUPSD_PID"
        wait "$CUPSD_PID"
    fi
}

wait_for_cups() {
    attempts=0

    until lpstat -r 2>/dev/null | grep -q "scheduler is running"; do
        if ! kill -0 "$CUPSD_PID" 2>/dev/null; then
            wait "$CUPSD_PID"
            exit $?
        fi

        attempts=$((attempts + 1))
        if [ "$attempts" -ge 30 ]; then
            echo "CUPS did not start within 30 seconds" >&2
            exit 1
        fi
        sleep 1
    done
}

discover_printer_uri() {
    lpinfo -v 2>/dev/null \
        | awk '$1 == "direct" && $2 ~ /^usb:\/\/DYMO\// { print $2; exit }'
}

configure_printer() {
    printer_uri="$PRINTER_URI"

    if [ -z "$printer_uri" ]; then
        printer_uri="$(discover_printer_uri)"
    fi

    if [ -z "$printer_uri" ]; then
        echo "No DYMO USB printer found; retrying in ${DISCOVERY_INTERVAL_SECONDS}s"
        return 1
    fi

    echo "Configuring ${PRINTER_NAME} at ${printer_uri}"
    lpadmin -p "$PRINTER_NAME" -E -v "$printer_uri" -m "$PRINTER_MODEL" \
        -o printer-is-shared=true
    lpadmin -d "$PRINTER_NAME"
    cupsenable "$PRINTER_NAME"
    cupsaccept "$PRINTER_NAME"

    echo "Configured printer queue: ${PRINTER_NAME}"
    lpstat -v "$PRINTER_NAME"
}

trap 'stop_cups; exit 0' INT TERM

echo "Starting CUPS"
cupsd -f &
CUPSD_PID=$!

wait_for_cups

until configure_printer; do
    if ! kill -0 "$CUPSD_PID" 2>/dev/null; then
        wait "$CUPSD_PID"
        exit $?
    fi
    sleep "$DISCOVERY_INTERVAL_SECONDS"
done

wait "$CUPSD_PID"
