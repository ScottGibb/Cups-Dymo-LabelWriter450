#!/bin/bash
# Launch cupds in the foreground
echo "INFO: Detected USB Connections"
lsusb
echo "INFO: Ended USB Connections"

echo "INFO:Starting Cups Demon"
/usr/sbin/cupsd 

echo "INFO:Cups Information:"
#Print Cups Info
lpinfo -v
echo "INFO: Ended Cups Information"

# echo "INFO:Adding Printer to Cups"
python3 -u add_printers.py
echo "INFO: End of Setup Script"
/usr/sbin/cupsd -f

