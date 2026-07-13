FROM debian:bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive

# Debian packages provide a maintained build of the legacy DYMO CUPS driver.
# Keeping the driver in the image avoids downloading an unverified, obsolete
# SDK at build time.
RUN apt-get update \
    && apt-get install --no-install-recommends --yes \
        cups \
        cups-client \
        cups-filters \
        printer-driver-dymo \
        tini \
        usbutils \
    && rm -rf /var/lib/apt/lists/*

COPY cupsd.conf /etc/cups/cupsd.conf
COPY setup.sh /usr/local/bin/configure-printer

RUN chmod 0755 /usr/local/bin/configure-printer

EXPOSE 631

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD lpstat -r | grep -q "scheduler is running" || exit 1

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/local/bin/configure-printer"]
