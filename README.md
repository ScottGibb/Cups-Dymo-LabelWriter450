# CUPS server for a DYMO LabelWriter 450

Run a network-accessible CUPS queue for a USB-connected DYMO LabelWriter 450
on a Raspberry Pi. The image uses Debian's packaged `printer-driver-dymo`
driver, automatically discovers the connected DYMO USB device, and exposes the
shared queue over IPP.

## What changed

The previous implementation depended on an old HTTP driver download, compiled
an unmaintained SDK during every build, started CUPS twice, hard-coded a
fictional printer serial number, and printed a label whenever the container
restarted. Those behaviours made startup fragile and could create unwanted
labels.

This version instead:

- uses the maintained Debian CUPS driver package;
- discovers the real `usb://DYMO/...` URI at runtime, with an optional override;
- starts one supervised CUPS process and waits until it is ready;
- retries safely if the USB printer is plugged in later;
- shares the queue as `dymo` over IPP; and
- never submits a print job by itself.

## Requirements

- A Raspberry Pi connected to the LabelWriter 450 by USB.
- A container runtime that supports the Pi. The original Raspberry Pi Zero W is
  ARMv6; the image is built for the compatible `linux/arm/v5` platform.
- Docker Compose v2 (`docker compose`) on the Raspberry Pi.

> Docker Desktop on macOS can validate the Compose file, but cannot validate
> this USB printer. Use the Raspberry Pi for the runtime steps below.

## Start it on the Raspberry Pi

```sh
git clone https://github.com/ScottGibb/Cups_Dymo-450.git
cd Cups_Dymo-450
cp .env.example .env
docker compose up -d --build
docker compose logs --follow cups
```

Once the logs report `Configured printer queue: dymo`, check the queue:

```sh
docker compose exec cups lpstat -t
```

The CUPS web interface is available at `http://<pi-hostname-or-ip>:631`. Add
the shared printer from another computer using:

```text
ipp://<pi-hostname-or-ip>:631/printers/dymo
```

## Configuration

The defaults in `docker-compose.yml` target a standard LabelWriter 450. Copy
`.env.example` to `.env` only when you need to pin the detected USB device,
rename the queue, or select another supported DYMO model.

The setup script looks for the first `usb://DYMO/...` device reported by CUPS.
When several DYMO printers are connected, set `PRINTER_URI` to the exact URI
shown by:

```sh
docker compose exec cups lpinfo -v
```

## Support and diagnostics

See [Raspberry Pi deployment and troubleshooting](docs/troubleshooting.md) for
hardware checks, a manual test print, and recovery steps.

## Continuous integration

GitHub Actions uses MegaLinter for shell, Dockerfile, YAML, JSON, Markdown, and
workflow checks. It creates a separate pull request when auto-formatting is
needed and builds the image as `linux/arm/v5`, which is compatible with the
original ARMv6 Raspberry Pi Zero W.

Dependabot checks GitHub Actions and the Docker base image every week. Release
Please generates release pull requests from Conventional Commits.

## License

GPL-3.0-or-later.
