# Cups_Dymo-450

[![Static-Analysis](https://github.com/ScottGibb/Cups_Dymo-450/actions/workflows/Static%20Analysis.yaml/badge.svg)](https://github.com/ScottGibb/Cups_Dymo-450/actions/workflows/Static%20Analysis.yaml)
[![Build](https://github.com/ScottGibb/Cups_Dymo-450/actions/workflows/Build.yaml/badge.svg)](https://github.com/ScottGibb/Cups_Dymo-450/actions/workflows/Build.yaml)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

<center>
<img src= "docs/Languages And Tools.png">
</center>

## Summary

This repository contains a Dockerfile which runs CUPS on Raspberry Pi. This project was aimed at making the Dymo LabelWriter 450 Wireless by adding a Raspberry Pi Zero to the setup.


## Architecture
The architecture of this project is as follows:

<center>
<img src= "docs/Architecture.png">
</center>

The key parts are as follows:

- Raspberry Pi Zero W: Responsible for running CUPS and the Dymo LabelWriter 450 Drivers inside a Docker container.

- Dymo LabelWriter 450: The printer which is connected to the Raspberry Pi Zero W via USB.

- PC: The PC which is connected to the Local Area Network. This is where the user will be printing from.

The container is designed so that the full install is done as soon as the container is started. As long as the USB Cable is plugged into the printer, the container should immediately attach this printer to CUPS and set it to the default printer.

## Installation

## Useful Links

This project was inspired by lots of other repositories and open source projects, which are linked below:

