# macOS client setup

Run these steps on the Mac that sends print jobs to the Raspberry Pi CUPS
server. Do not run the client helper inside the Pi's CUPS container.

To expose the named DYMO label stocks, install the DYMO printer software on
each Mac. Bonjour finds the queue, but macOS can attach the wrong software
automatically. Printing may still work with AirPrint or Generic PostScript,
while the print dialogue shows only office paper sizes or unnamed custom
dimensions instead of the DYMO label stocks.

For this project, the **Use** field must be set to **DYMO LabelWriter 450** when
the printer is added. The queue must then be adjusted with this repository's
macOS helper so the Pi does not run the DYMO raster filter a second time.

## Before adding the printer

1. Check that the Pi and Mac are on the same local network and that the Pi logs
   report `Configured printer queue: dymo`.
2. Install the compatible macOS software for the LabelWriter 450 from the
   [official DYMO support page](https://www.dymo.co.uk/support?cfid=user-guide).
   The printer does not need to be connected to the Mac by USB.
3. Confirm that the driver is available in Terminal:

   ```sh
   lpinfo -m | grep 'DYMO LabelWriter 450'
   ```

   Continue only when the command lists `DYMO LabelWriter 450`. If it returns
   nothing, reinstall the DYMO software before adding the network queue.

4. Confirm that Bonjour can see the queue shared by the Pi:

   ```sh
   ippfind -T 10 _ipp._tcp _ipps._tcp --ls
   ```

   The result should include an `ipp://` or `ipps://` address ending in
   `/printers/dymo`. A Pi using both Ethernet and Wi-Fi may appear more than
   once; this is expected.

## Recommended: add the Bonjour printer

1. Open **System Settings > Printers & Scanners**.
2. Select **Add Printer, Scanner or Fax**.
3. On the **Default** tab, select
   **DYMO LabelWriter 450 @ &lt;pi-hostname&gt;**.
4. Wait for macOS to finish gathering the printer information.
5. Open the **Use** menu, choose **Select Software**, select
   **DYMO LabelWriter 450**, and select **OK**.
6. Check that **Use** now says **DYMO LabelWriter 450**, then select **Add**.

Do not leave **Use** set to **AirPrint**, **Generic PostScript Printer**, or a
generic DYMO model. Those choices do not provide the LabelWriter 450 stock
definitions used by this setup.

## Make the DYMO driver safe for the network queue

The stock DYMO PPD describes its output as CUPS Raster even after the Mac's
`raster2dymolw` filter has converted it to printer-ready DYMO data. A remote
CUPS server therefore tries to rasterize those bytes again and stops with
`Unable to open raster file - : No such file or directory`.

From the repository directory on the Mac, find the local queue name and run the
network-queue helper:

```sh
lpstat -p
sudo ./scripts/configure-macos-queue.sh DYMO_LabelWriter_450
```

Replace `DYMO_LabelWriter_450` if `lpstat` reports another name. The helper
changes only that local queue's PPD: it retains the named label stocks and DYMO
filter, but declares the filter output as `application/vnd.cups-raw` so the Pi
passes it directly to USB. It does not submit a print job.

This uses the standard
[`cupsFilter2` source and destination format declaration](https://openprinting.github.io/cups/doc/spec-ppd.html#cupsFilter2)
defined by CUPS.

Run the helper again whenever the printer is removed and re-added or its driver
is replaced. It is safe to rerun and reports when the queue is already
configured.

## Fallback: add the printer by address

Use this method if Bonjour discovery is unavailable:

1. Open **System Settings > Printers & Scanners**.
2. Select **Add Printer, Scanner or Fax**, then select the **IP** tab.
3. Enter these values:

   | Field    | Value                                      |
   | -------- | ------------------------------------------ |
   | Address  | `<pi-hostname-or-ip>`                      |
   | Protocol | **Internet Printing Protocol - IPP**       |
   | Queue    | `printers/dymo`                            |
   | Name     | `DYMO LabelWriter 450`                     |
   | Location | Optional                                   |
   | Use      | **Select Software > DYMO LabelWriter 450** |

   Replace `<pi-hostname-or-ip>` with the hostname or reserved IP address for
   your Pi, and replace `dymo` if `PRINTER_NAME` was changed. Put only the
   hostname or IP address in **Address**; do not paste the full IPP URL into
   that field.

4. Check the **Use** field again, then select **Add**.
5. Run the network-queue helper from the previous section.

The equivalent complete printer URI is:

```text
ipp://<pi-hostname-or-ip>:631/printers/dymo
```

## Verify the driver before printing

Find the local macOS queue name:

```sh
lpstat -p
```

Then inspect its connection and paper sizes, replacing the example queue name
if necessary:

```sh
lpstat -v DYMO_LabelWriter_450
lpoptions -p DYMO_LabelWriter_450 -l | grep '^PageSize/'
grep '^\*cupsFilter' /etc/cups/ppd/DYMO_LabelWriter_450.ppd
```

A correctly configured queue lists many DYMO `PageSize` choices and options
such as print quality or density. A queue that lists only sizes such as
`Letter`, `Legal`, and `A4` was added with the wrong software and should be
removed and added again.

The filter check must show a `cupsFilter2` line containing both
`application/vnd.cups-raster` and `application/vnd.cups-raw`. A legacy
`cupsFilter` line means the helper has not been applied and the Pi may filter
the job twice.

Close and reopen the application or its print dialogue after adding the queue.
Select the DYMO label stock that is physically loaded before the first print;
macOS can save that choice as a print preset for later jobs.

## Repair a queue added with the wrong software

1. In **System Settings > Printers & Scanners**, Control-click the incorrect
   printer and select **Remove Printer**.
2. Confirm that `lpinfo -m | grep 'DYMO LabelWriter 450'` finds the driver.
3. Add the printer again using the Bonjour or IP steps above.
4. Before selecting **Add**, verify that **Use** says
   **DYMO LabelWriter 450**.
5. Run `sudo ./scripts/configure-macos-queue.sh <local-queue-name>` from this
   repository.
6. Run `lpoptions -p <local-queue-name> -l` and confirm that DYMO label stocks
   are now present.

Alternatively, repair an existing queue in place from Terminal. First use
`lpinfo -m | grep 'DYMO LabelWriter 450'` to confirm the model identifier, then
apply it to the local queue:

```sh
sudo lpadmin -p DYMO_LabelWriter_450 \
  -m Library/Printers/PPDs/Contents/Resources/lw450.ppd.gz
sudo ./scripts/configure-macos-queue.sh DYMO_LabelWriter_450
```

Replace both the queue name and model identifier with the values reported on
that Mac. CUPS prints a deprecation warning because the LabelWriter 450 uses a
legacy vendor driver; that warning is expected. The second command changes the
legacy filter declaration to a network-safe `cupsFilter2` declaration. Do not
substitute `-m everywhere`, which creates a driverless queue and may lose the
named DYMO stock list. Rerun the verification commands before printing.

Apple also documents the
[printer-addition fields](https://support.apple.com/en-gb/guide/mac-help/mh14004/mac)
and recommends
[removing and re-adding a printer with different software](https://support.apple.com/en-gb/guide/mac-help/mchlp1077/mac)
when expected print options are missing.
