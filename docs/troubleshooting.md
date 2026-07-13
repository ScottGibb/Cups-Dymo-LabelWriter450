# Raspberry Pi deployment and troubleshooting

This project needs to be run on the Raspberry Pi that has the LabelWriter
connected over USB. A macOS Docker Desktop run cannot validate USB detection
or print a label.

## Before starting

1. Connect and power on the DYMO LabelWriter 450.
2. On the Raspberry Pi, verify that Linux sees it:

   ```sh
   lsusb | grep -i dymo
   ```

3. Confirm that the container runtime itself works on the Pi. The original
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

## Add the shared printer from another computer

Use this IPP address, replacing `raspberrypi.local` and `dymo` if you changed
the hostname or `PRINTER_NAME`:

```text
ipp://raspberrypi.local:631/printers/dymo
```

The read-only CUPS interface is available at `http://raspberrypi.local:631`.
Administrative configuration is intentionally restricted; administer the queue
from the Raspberry Pi with `docker compose exec cups lpadmin ...`.

## Common failures

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
