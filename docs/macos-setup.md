# Add the DYMO printer correctly on macOS

To expose the named DYMO label stocks, install the DYMO printer software on
each Mac. Bonjour finds the queue, but macOS can attach the wrong software
automatically. Printing may still work with AirPrint or Generic PostScript,
while the print dialogue shows only office paper sizes or unnamed custom
dimensions instead of the DYMO label stocks.

For this project, the **Use** field must be set to **DYMO LabelWriter 450** when
the printer is added.

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

## Fallback: add the printer by address

Use this method if Bonjour discovery is unavailable:

1. Open **System Settings > Printers & Scanners**.
2. Select **Add Printer, Scanner or Fax**, then select the **IP** tab.
3. Enter these values:

   | Field    | Value                                         |
   | -------- | --------------------------------------------- |
   | Address  | `pilab.local` or the Pi's reserved IP address |
   | Protocol | **Internet Printing Protocol - IPP**          |
   | Queue    | `printers/dymo`                               |
   | Name     | `DYMO LabelWriter 450`                        |
   | Location | Optional                                      |
   | Use      | **Select Software > DYMO LabelWriter 450**    |

   Replace `pilab.local` if the Pi uses a different hostname, and replace
   `dymo` if `PRINTER_NAME` was changed. Put only the hostname or IP address in
   **Address**; do not paste the full IPP URL into that field.

4. Check the **Use** field again, then select **Add**.

The equivalent complete printer URI is:

```text
ipp://pilab.local:631/printers/dymo
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
```

A correctly configured queue lists many DYMO `PageSize` choices and options
such as print quality or density. A queue that lists only sizes such as
`Letter`, `Legal`, and `A4` was added with the wrong software and should be
removed and added again.

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
5. Run `lpoptions -p <local-queue-name> -l` and confirm that DYMO label stocks
   are now present.

Alternatively, repair an existing queue in place from Terminal. First use
`lpinfo -m | grep 'DYMO LabelWriter 450'` to confirm the model identifier, then
apply it to the local queue:

```sh
sudo lpadmin -p DYMO_LabelWriter_450 \
  -m Library/Printers/PPDs/Contents/Resources/lw450.ppd.gz
```

Replace both the queue name and model identifier with the values reported on
that Mac. CUPS prints a deprecation warning because the LabelWriter 450 uses a
legacy vendor driver; that warning is expected. Do not substitute
`-m everywhere`, which creates a driverless queue and may lose the named DYMO
stock list. Rerun the verification commands before printing.

Apple also documents the
[printer-addition fields](https://support.apple.com/en-gb/guide/mac-help/mh14004/mac)
and recommends
[removing and re-adding a printer with different software](https://support.apple.com/en-gb/guide/mac-help/mchlp1077/mac)
when expected print options are missing.
