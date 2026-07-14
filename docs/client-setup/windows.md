# Windows client setup

Run these steps on the Windows computer that sends print jobs to the Raspberry
Pi CUPS server. The LabelWriter remains connected to the Pi by USB.

Windows must create the network queue with the model-specific DYMO driver and
the `RAW` spool datatype. Adding the Pi with `Add-Printer -IppURL` creates a
Microsoft IPP Class Driver queue instead. That generic queue can omit the
LabelWriter 450 stock definitions that the print dialogue needs.

The Windows helper creates an HTTP/IPP printer port and binds the installed
DYMO driver in one operation. Microsoft's HTTP print provider transports the
driver's RAW output over IPP, so the Pi does not run the DYMO conversion a
second time.

## Before running the helper

1. Install the compatible LabelWriter 450 software from the
   [official DYMO support page](https://www.dymo.com/support?cfid=user-guide).
   The printer remains connected to the Pi by USB.
2. Open **Windows PowerShell** as Administrator.
3. Confirm the exact installed driver name:

   ```powershell
   Get-PrinterDriver |
     Where-Object Name -Match 'DYMO.*450' |
     Select-Object Name
   ```

   Continue only when a model-specific LabelWriter 450 driver is listed. Pass
   its exact name to `-DriverName` if it differs from
   `DYMO LabelWriter 450`.

4. Check **Settings > Bluetooth & devices > Printers & scanners > Printer
   preferences**. Windows Protected Print Mode must be off to use the legacy
   DYMO driver. Microsoft documents that this mode removes and blocks
   third-party printer drivers. The helper reports the conflict but never
   changes this security setting for you.

## Create the queue

From the repository directory in the elevated Windows PowerShell window:

```powershell
$IppUri = 'ipp://<pi-hostname-or-ip>:631/printers/dymo'

.\scripts\configure-windows-queue.ps1 `
  -IppUri $IppUri `
  -PrinterName 'DYMO LabelWriter 450' `
  -DriverName 'DYMO LabelWriter 450'
```

Replace `<pi-hostname-or-ip>` with the hostname or reserved IP address for
your Pi, and replace `dymo` if `PRINTER_NAME` was changed on the server. The
IPP URI is deliberately required; the printer and driver names use the values
shown above by default, so the shorter form is:

```powershell
.\scripts\configure-windows-queue.ps1 -IppUri $IppUri
```

Earlier versions of the helper used a site-specific default local queue name.
Before the first run after upgrading, check for an existing DYMO queue:

```powershell
Get-Printer | Where-Object DriverName -Match 'DYMO.*450' |
  Select-Object Name, DriverName, PortName
```

If one is already configured, pass its exact reported name so the helper
validates or replaces that queue instead of creating a second one:

```powershell
$IppUri = 'ipp://<pi-hostname-or-ip>:631/printers/dymo'
$PrinterName = '<existing-local-queue-name>'
.\scripts\configure-windows-queue.ps1 `
  -IppUri $IppUri `
  -PrinterName $PrinterName
```

The helper converts the CUPS URI to Windows' supported
`http://<pi-hostname-or-ip>:631/printers/dymo/.printer` form. It checks the
local driver, Internet Printing Client feature, Pi connection, port type,
selected driver, and `RAW` datatype. It is idempotent and never prints a test
page.

This follows the
[Windows URL-printing model](https://learn.microsoft.com/en-us/windows-hardware/drivers/print/printing-to-urls-from-applications)
and the
[CUPS URI form for Windows IPP clients](https://openprinting.github.io/cups/doc/network.html#PROTOCOLS).
Do not create a Standard TCP/IP port on TCP 631: that port type sends a raw
socket stream, while the Pi expects the IPP protocol on port 631.

## Replace an incorrectly added queue

When a printer with the requested name already uses a class driver, generic
driver, or wrong port, the helper stops without changing it. Close any print
dialogues, clear or finish its jobs, then opt in to replacement. If the
migration check found a differently named existing queue, also pass
`-PrinterName $PrinterName` to this command:

```powershell
$IppUri = 'ipp://<pi-hostname-or-ip>:631/printers/dymo'
.\scripts\configure-windows-queue.ps1 -IppUri $IppUri -Replace
```

The helper first creates and verifies a staging queue. It then swaps the queues
and preserves the old queue as a backup after the new one passes validation.
It also preserves the default-printer choice. If the swap fails, it verifies
the restored old queue and retains any temporary queue for inspection. If
Windows blocks rollback, the error reports the backup queue's exact name
instead of deleting it. The helper serializes its own setup runs and never
deletes a printer queue or queued jobs automatically.

After a successful replacement, the helper prints the backup queue's exact
name. Confirm that it has no jobs before removing it manually:

```powershell
Get-PrintJob -PrinterName '<reported backup queue name>'
Remove-Printer -Name '<reported backup queue name>'
```

Preview either creation or replacement without making changes with `-WhatIf`:

```powershell
$IppUri = 'ipp://<pi-hostname-or-ip>:631/printers/dymo'
.\scripts\configure-windows-queue.ps1 -IppUri $IppUri -Replace -WhatIf
```

## Verify without printing

Replace the name below if you deliberately selected a different local queue
name:

```powershell
Get-Printer -Name 'DYMO LabelWriter 450' -Full |
  Format-List Name, DriverName, PortName, Datatype
```

The result must show:

- `DriverName`: the model-specific DYMO LabelWriter 450 driver;
- `PortName`: an address ending in `/printers/dymo/.printer`; and
- `Datatype`: `RAW`.

Open **Printing preferences** for the queue and confirm that the expected DYMO
label stocks appear before submitting the first print.

If the driver cannot be installed, review Microsoft's
[Windows Protected Print Mode documentation](https://learn.microsoft.com/en-us/windows/modern-print/windows-protected-print-mode/windows-protected-print-mode).
Disabling that mode permits the required legacy driver but gives up the
additional protection of Microsoft's modern driverless print stack.
