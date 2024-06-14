#!/bin/bash
# Launch cupds in the foreground
echo "INFO: Detected USB Connections"
lsusb
echo "INFO:Starting Cups Demon"
/usr/sbin/cupsd 

echo "INFO:Cups Information:"
#Print Cups Info
lpinfo -v

echo "INFO:Adding Printer to Cups"
python3 -u ./addprinters.py
/usr/sbin/cupsd -f

