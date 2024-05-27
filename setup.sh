#!/bin/bash
# Launch cupds in the foreground
echo "INFO:Starting Cups Demon"
/usr/sbin/cupsd

echo "INFO:Cups Information:"
#Print Cups Info
lpinfo -v

echo "INFO:Adding Printer to Cups"
# Add the printer
lpadmin -p dymo -v usb://DYMO/LabelWriter%20450?serial=01010112345600 -P /usr/share/cups/model/lw450.ppd

echo "INFO:Print Cups Stats"
# Stats
lpstat -v

echo "INFO:Start Dymo Printer and accept new Jobs"
# Start and Accept Jobs
cupsenable dymo
cupsaccept dymo

echo "INFO:Setting Default Printer"
# Set Default Printer
lpoptions -d dymo

echo "INFO:Finished Setup! XD"

# Test Print
echo "INFO:Printing Label"
lp -d dymo test.txt
echo "INFO: Label Printed"

# Keep the container running
/usr/sbin/cupsd -f
