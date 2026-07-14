# Client setup

These guides are for the computer that sends print jobs to the Raspberry Pi.
They do not configure or rebuild the CUPS server, and the LabelWriter remains
connected to the Pi by USB.

Complete the [Raspberry Pi server setup](../../README.md#start-it-on-the-raspberry-pi)
first. Continue here after the Pi logs report `Configured printer queue: dymo`
and the shared queue is reachable at:

```text
ipp://<pi-hostname-or-ip>:631/printers/dymo
```

Replace `<pi-hostname-or-ip>` with the hostname or reserved IP address of your
Pi. The Linux and Windows guides store the complete deployment-specific
address in an `IPP_URI`/`IppUri` variable instead of assuming a hostname.

## Choose the client operating system

| Client  | Setup guide           | Client-side helper                    |
| ------- | --------------------- | ------------------------------------- |
| macOS   | [macOS](macos.md)     | `scripts/configure-macos-queue.sh`    |
| Linux   | [Linux](linux.md)     | `scripts/configure-linux-queue.sh`    |
| Windows | [Windows](windows.md) | `scripts/configure-windows-queue.ps1` |

Each client needs the model-specific DYMO LabelWriter 450 driver to expose the
named label stocks. The helper then makes that local client queue send
printer-ready data to the Pi without applying the DYMO conversion twice.

Do not run these helpers inside the CUPS container. For USB discovery,
Bonjour, container, or Raspberry Pi failures, use the
[server troubleshooting guide](../troubleshooting.md).
