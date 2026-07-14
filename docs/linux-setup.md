# Add the DYMO printer correctly on Linux

Linux clients need a persistent local CUPS queue with the packaged DYMO
LabelWriter 450 driver. A temporary `cups-browsed` queue or an IPP Everywhere
queue can hide the named label stocks. An unmodified DYMO PPD can also cause
the Pi to run `raster2dymolw` twice.

The Linux helper keeps the model-specific label list, but declares the local
filter's printer-ready output as `application/vnd.cups-raw`. The Pi then sends
those bytes directly to the USB printer instead of filtering them again.

## Install the CUPS and DYMO packages

On Debian, Ubuntu, Raspberry Pi OS, and their derivatives:

```sh
sudo apt update
sudo apt install cups printer-driver-dymo
sudo systemctl enable --now cups
```

Confirm that the exact LabelWriter 450 model is available:

```sh
lpinfo -h localhost -m | grep 'DYMO LabelWriter 450'
```

Other distributions can use the helper when they provide the same
`lw450.ppd` model and `raster2dymolw` filter. Install those from the
distribution's package manager; this repository does not download or install
printer drivers automatically.

## Create an explicit local network queue

Do not use an automatically generated `implicitclass://` queue. Either add a
printer manually in the desktop printer settings with this address and select
**DYMO LabelWriter 450**, or create the queue from a terminal:

```sh
sudo lpadmin -h localhost -p DYMO_LabelWriter_450 -E \
  -v 'ipp://pilab.local:631/printers/dymo' \
  -m dymo:0/cups/model/lw450.ppd \
  -o printer-is-shared=false
```

Replace `pilab.local` if the Pi has another hostname, and replace `dymo` if
`PRINTER_NAME` was changed. If `lpinfo -h localhost -m` reports a different
model identifier for the exact LabelWriter 450, use that identifier after
`-m`.

## Make the queue safe for remote printing

From the repository directory on the Linux client, run:

```sh
sudo ./scripts/configure-linux-queue.sh DYMO_LabelWriter_450
```

Replace the argument if the local queue has another name. The helper:

- targets only the local CUPS scheduler, even when `CUPS_SERVER` is set;
- accepts only an explicit IPP, IPPS, or DNS-SD network queue;
- verifies the exact LabelWriter 450 PPD and its named label stocks;
- verifies that the PPD's `raster2dymolw` filter is executable;
- briefly stops the queue from accepting new jobs, refuses to change the PPD
  while jobs are queued, and restores its previous accepting state;
- keeps the local proxy queue private so it is not advertised as another
  forwarding queue;
- replaces the single legacy `cupsFilter` declaration with a network-safe
  `cupsFilter2` declaration;
- restores the original PPD if CUPS does not retain the change; and
- never submits a print job.

It is safe to rerun. Run it again after removing and re-adding the printer or
after replacing its driver.

The change uses the standard
[`cupsFilter2` source and destination format declaration](https://openprinting.github.io/cups/doc/spec-ppd.html#cupsFilter2).
CUPS marks PPDs, printer drivers, and filters as deprecated, so this helper is
for current CUPS 2.x systems that still support the legacy DYMO driver.

## Verify without printing

```sh
lpstat -h localhost -v DYMO_LabelWriter_450
lpoptions -h localhost -p DYMO_LabelWriter_450 -l | grep '^PageSize/'
sudo grep '^\*cupsFilter' /etc/cups/ppd/DYMO_LabelWriter_450.ppd
```

The device URI must point to the Pi, the `PageSize` output must contain many
named DYMO stocks, and the PPD must contain one `cupsFilter2` line with both
`application/vnd.cups-raster` and `application/vnd.cups-raw`. The client queue
is intentionally not shared; only the Pi should advertise the physical
printer.

If the filter check still shows only `cupsFilter`, do not print. Rerun the
helper and follow its error message. To restore Debian's stock PPD manually:

```sh
sudo lpadmin -h localhost -p DYMO_LabelWriter_450 \
  -m dymo:0/cups/model/lw450.ppd
```

The stock PPD reintroduces the remote double-filter problem, so rerun the
helper before printing through the Pi.
