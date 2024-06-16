"""
This script was taken and adapted from this
repository:
https://github.com/Westwoodlabs/web2dymo-docker.
Special Thanks to WestWoodLabs!!
"""

import time
import sys
import os
import subprocess
import logging

TEST_FILE_PATH = "test.txt"
INIT_PERIOD_S=10

print("Adding printers to CUPS..")

# Check if cups is online
while True:
    p = subprocess.Popen(
        ["lpstat", "-o"], stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )
    stdout, stderr = p.communicate()
    if p.returncode == 0:
        break
    else:
        print("Wait for cupsd to be ready...")
        time.sleep(1)

print("cupsd is ready")

TOTAL_PRINTER_COUNT = 0
ENABLED_PRINTER_COUNT = 0

i = 0
while True:
    i = i + 1
    printerEnable = os.getenv(f"PRINTER{i}_ENABLE")
    if printerEnable is None:
        break
    TOTAL_PRINTER_COUNT += 1

    if not printerEnable == "1":
        continue
    ENABLED_PRINTER_COUNT += 1

    # Get printer Variables
    printer_name = os.getenv(f"PRINTER{i}_NAME")
    printer_dev_uri = os.getenv(f"PRINTER{i}_DEVURI")
    printer_driver = os.getenv(f"PRINTER{i}_DRIVER")

    # Add Printer
    print(f"Adding printer '{printer_name}'")

    # Call Subprocesses to add printer to cups
    subprocess.call(
        f"lpadmin -p {printer_name} -E -v {printer_dev_uri} -v {printer_driver}", shell=True
    )
    subprocess.call(f"cupsenable {printer_name}", shell=True)
    subprocess.call(f"cupsaccept {printer_name}", shell=True)
    subprocess.call(f"lpoptions -d {printer_name}", shell=True)  # Set Default Printer to this one
    print(f"Printer '{printer_name}' added")
    print(f"Waiting {INIT_PERIOD_S}s")
    time.sleep(INIT_PERIOD_S)
    print("Printing test Page!")
    subprocess.call(
        "lp -d {printer_name} {TEST_FILE_PATH}", shell=True
    )  # Print Test Page
    print("Printed test Page!")

print(f"{ENABLED_PRINTER_COUNT}/{TOTAL_PRINTER_COUNT} enabled Printers.")
time.sleep(3)  # Sleep for 3 seconds
if ENABLED_PRINTER_COUNT == 0:
    logging.critical("Failed to add printers/no printers were enabled")
    sys.exit(-1)
sys.exit(0)
