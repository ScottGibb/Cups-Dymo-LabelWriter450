# Raspberry Pi server deployment and troubleshooting

This is the server-side guide. Run these steps on the Raspberry Pi that has the
LabelWriter connected over USB. For the Mac, Linux PC, or Windows PC that sends
jobs to the Pi, use the [client setup guides](client-setup/README.md).

A macOS Docker Desktop run cannot validate USB detection or print a label.

## Before starting

1. Connect and power on the DYMO LabelWriter 450.
2. Check the Raspberry Pi OS architecture:

   ```sh
   uname -m
   ```

   Use `linux/arm/v7` for an `armv7l` Pi 4, or `linux/arm64` for an `aarch64`
   Pi 4 or Pi 5. The original `armv6l` Pi Zero uses `linux/arm/v5`.

3. On the Raspberry Pi, verify that Linux sees the printer:

   ```sh
   lsusb | grep -i dymo
   ```

4. Confirm that the container runtime itself works on the Pi. The original
   Raspberry Pi Zero W has an ARMv6 processor; this image targets the compatible
   `linux/arm/v5` Debian image. Recent official Docker Engine packages do not
   support ARMv6, so keep the already-working runtime or use a compatible
   container runtime for that Pi.

## Start the service

From the project directory on the Raspberry Pi:

```sh
cp .env.example .env
docker compose up -d --build
docker compose logs --follow cups
```

The first successful startup prints `Configured printer queue: dymo` in the
container logs. The service stays running and retries every ten seconds when
the printer is connected after the container starts.

The logs also report whether the host D-Bus socket is available for Bonjour
advertisement. CUPS uses that socket to register the queue with the existing
Avahi daemon on the Raspberry Pi.

## Verify the printer queue

```sh
docker compose exec cups lpstat -t
docker compose exec cups lpinfo -v
docker compose exec cups lpinfo -m | grep 'LabelWriter 450'
```

For a basic hardware test after the queue is configured, load a label and run:

```sh
printf 'DYMO test\n' | docker compose exec -T cups lp -d dymo
```

The container deliberately never prints a test label automatically.

## Connect a client computer

On Macs and Linux desktops with DNS-SD support, the printer should appear as
`DYMO LabelWriter 450 @ <pi-hostname>`. Verify the advertisement with:

```sh
ippfind -T 10 _ipp._tcp _ipps._tcp --ls
```

Follow the platform-specific [macOS](client-setup/macos.md),
[Linux](client-setup/linux.md), or [Windows](client-setup/windows.md) client
guide. Discovery does not guarantee that the client selects the DYMO driver or
transports its printer-ready output correctly.

Use this IPP address, replacing `raspberrypi.local` and `dymo` if you changed
the hostname or `PRINTER_NAME`, when manual configuration is needed:

```text
ipp://raspberrypi.local:631/printers/dymo
```

The read-only CUPS interface is available at `http://raspberrypi.local:631`.
Administrative configuration is intentionally restricted; administer the queue
from the Raspberry Pi with `docker compose exec cups lpadmin ...`.

## Common failures

### macOS shows Letter and A4 instead of DYMO label sizes

macOS may add the Bonjour queue as a Generic PostScript Printer. That driver
contains only general office paper sizes and ignores the label definitions
advertised by the Pi.

Check the local queue on the Mac, replacing the queue name when necessary:

```sh
lpoptions -p DYMO_LabelWriter_450 -l
```

If `PageSize` lists only values such as `Letter`, `Legal`, and `A4`, follow the
[macOS client setup and repair guide](client-setup/macos.md). Remove the queue and add it
again with **Use > Select Software > DYMO LabelWriter 450**. Do not leave the
queue set to AirPrint or Generic PostScript Printer.

The named label stocks require the DYMO printer software on the Mac. The Pi
still performs network sharing and accepts the resulting printer-ready job; the
DYMO remains physically connected only to the Pi.

### A Mac job stops with `Unable to open raster file`

The unmodified DYMO Mac PPD labels its printer-ready output as CUPS Raster. The
Pi then invokes `raster2dymolw` a second time and cannot interpret the DYMO
command stream as a raster file.

Cancel the stopped Mac job, then run the network-queue helper from the
repository directory on the Mac:

```sh
cancel -a DYMO_LabelWriter_450
sudo ./scripts/configure-macos-queue.sh DYMO_LabelWriter_450
```

Replace the queue name with the value from `lpstat -p`. The helper is
idempotent, preserves the named label sizes, and never submits a test print.
Verify the result before retrying:

```sh
grep '^\*cupsFilter' /etc/cups/ppd/DYMO_LabelWriter_450.ppd
```

The output must be a `cupsFilter2` declaration containing
`application/vnd.cups-raw`. If the printer is later removed and re-added, run
the helper again.

### Linux shows generic sizes or a job is filtered twice

An auto-discovered `implicitclass://` queue or a queue using IPP Everywhere
does not provide the required local DYMO driver path. A persistent queue with
the stock Linux DYMO PPD can expose the labels but still describes its final
output as CUPS Raster, causing the same double-filter failure as an unmodified
Mac queue.

Follow the [Linux client setup guide](client-setup/linux.md) to create an explicit IPP queue
with `dymo:0/cups/model/lw450.ppd`, then run:

```sh
sudo ./scripts/configure-linux-queue.sh DYMO_LabelWriter_450
```

The helper refuses temporary, generic, USB, or active queues and automatically
restores the original PPD if verification fails. It does not require a Pi image
rebuild and does not print a test label.

### Windows does not show the DYMO stocks

`Add-Printer -IppURL` creates a Microsoft IPP Class Driver queue. For this
legacy LabelWriter, that can omit the model-specific label definitions. Install
the DYMO driver, close or finish jobs on the incorrect queue, and run the
[Windows client setup guide](client-setup/windows.md) from an elevated Windows PowerShell:

```powershell
.\scripts\configure-windows-queue.ps1 -Replace
```

The result must use the DYMO LabelWriter 450 driver, a port ending in
`/printers/dymo/.printer`, and the `RAW` datatype. The helper will not use a
Standard TCP/IP port because TCP 631 on the Pi expects IPP, not a raw socket
stream.

If the helper cannot find the DYMO driver, install it from DYMO first. Windows
Protected Print Mode must be off because it blocks third-party printer drivers;
the helper reports this requirement but never changes the setting itself.

### No DYMO USB printer found

The container can see only devices explicitly mapped by Compose. Check both the
host and the container:

```sh
lsusb | grep -i dymo
docker compose exec cups lsusb
docker compose exec cups lpinfo -v
```

If the container sees the printer but auto-discovery selects the wrong device,
copy its exact `usb://DYMO/...` URI into `.env` as `PRINTER_URI` and recreate the
container:

```sh
docker compose up -d --force-recreate
```

### The queue exists but jobs stop

Inspect the CUPS error log and the queue state:

```sh
docker compose exec cups tail -n 100 /var/log/cups/error_log
docker compose exec cups lpstat -t
```

The built-in Debian `printer-driver-dymo` package owns the driver and model
definition; there is no separate DYMO SDK download or source compilation step.

### The printer does not appear over Bonjour

The Pi must run Avahi, and the container must be able to reach it through the
host system D-Bus socket. Check all three points on the Pi:

```sh
systemctl is-active avahi-daemon
test -S /run/dbus/system_bus_socket
docker compose exec cups test -S /run/dbus/system_bus_socket
```

If Avahi is installed but inactive, enable it and recreate the container:

```sh
sudo systemctl enable --now avahi-daemon
docker compose up -d --force-recreate
```

Bonjour uses multicast UDP port 5353 on the local network. Guest Wi-Fi, client
isolation, VLAN boundaries, and restrictive firewalls can prevent discovery
even while direct IPP printing on TCP port 631 still works. A Pi connected by
both Ethernet and Wi-Fi may advertise the same service on both interfaces; this
is expected.
