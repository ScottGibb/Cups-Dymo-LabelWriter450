# Cups_Dymo-450

[![Static-Analysis](https://github.com/ScottGibb/Cups_Dymo-450/actions/workflows/Static%20Analysis.yaml/badge.svg)](https://github.com/ScottGibb/Cups_Dymo-450/actions/workflows/Static%20Analysis.yaml)
[![Build](https://github.com/ScottGibb/Cups_Dymo-450/actions/workflows/Build.yaml/badge.svg)](https://github.com/ScottGibb/Cups_Dymo-450/actions/workflows/Build.yaml)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

!["languages and tools](./docs/Languages%20And%20Tools.png)

## Summary

This repository contains a Dockerfile which runs CUPS on Raspberry Pi. This project was aimed at making the Dymo LabelWriter 450 Wireless by adding a Raspberry Pi Zero to the setup.

## Architecture

The architecture of this project is as follows:

![Architecture](./docs/Architecture.png)

The key parts are as follows:

- Raspberry Pi Zero W: Responsible for running CUPS and the Dymo LabelWriter 450 Drivers inside a Docker container.

- Dymo LabelWriter 450: The printer is connected to the Raspberry Pi Zero W via USB.

- PC: The PC is connected to the Local Area Network. This is where the user will be printing from.

The container is designed so that the full installation is done as soon as the container is started. As long as the USB Cable is plugged into the printer, the container should immediately attach this printer to CUPS and set it to the default printer.

## Installation

As for installing the software, the best way of installing this is to use the Dockerfile provided in this repository. This will build the image and run the container. The steps for this are as follows:

1. Clone the repository to the Raspberry Pi Zero W.
2. Run the following command to build the image and run the container, using the docker-compose.yml file, the --build will force the building of the container using the Dockerfile:

    ```bash
    docker-compose up -d --build
    ```

3. The container should now be running and the printer should be available on the network.
4. To check that the container is running, run the following command:

```bash
docker ps
```

## Directory Structure

The following is the directory structure of the project:

```bash
tree -L 1
.
├── conf
├── docker-compose.yml
├── Dockerfile
├── docs
├── ppd
├── ReadMe.md
├── ruff.toml
├── scripts
└── test.txt
```

- conf: is the configuration folder for cups
- ppd: is the PostScript Printer Description files for the Dymo LabelWriters
- docs: All diagrams and related documentation goes here
- scripts: the scripts that go inside the docker container, for more information read [this](./scripts/ReadMe.md).

## Setting up your Windows Device

When setting up windows you will need to do the following steps:

You must first download Dymo Connect before adding the cups printer to your windows 10 installation. This is due to the drivers being a part of dymo connect.

[Installation Link](https://download.dymo.com/dymo/Software/Win/DCDSetup1.4.6.37.exe)

![Stage 1 Windows 10](./docs/windows-10-add-printer-1.png)
![Stage 1 Windows 10](./docs/windows-10-add-printer-2.png)

You should then be able to use the printer from the rest of windows.

## Setting up the Dymo LabelWriter using the CUPS UI

If for some reason you are like myself, in which the auto setup does not seem to work correctly and the printer is always
""Waiting for printer to become available." Then you will have to set up the printer manually, like so:

### Step 1: Go to Administration and add a printer

![alt text](./docs/cups%20setup%20gui/image.png)
![alt text](./docs/cups%20setup%20gui/image-1.png)

### Step 2: Select Dymo LabelWriter

![alt text](./docs/cups%20setup%20gui/image-2.png)

### Step 3: Rename and Share

![alt text](./docs/cups%20setup%20gui/image-3.png)

### Step 4: Select Dymo LabelWriter 450

![alt text](./docs/cups%20setup%20gui/image-4.png)
Im not sure why there is two options of everything

### Step 5: Set your printer options

![alt text](./docs/cups%20setup%20gui/image-5.png)
This seems to happen a lot [issue](https://forums.raspberrypi.com/viewtopic.php?t=333307)

## Known Issues

### Google Chrome Print Pages

For some reason chrome doesnt always have the printer pages imediately, in this case swapping between the printers
seems to work and it eventually shows.

### Google Chrome No fit to scale

For some reason chrome doesnt have the fit to scale option anymore, no idea why that is.

## Continuous Integration Pipelines

Within this repository, there are two workflows:

- Static Analysis: This performs Linting on all the main filetypes of this repository such as Dockerfiles, Markdown files and Shell Scripts.

- Build: This performs the building of the Docker Image ensuring that it can be built. This is done using a Self-hosted GitHub Runner.

## Useful Links

This project was inspired by lots of other repositories and open-source projects, which are linked below:

- [Dymo LabelWriter 450](https://www.dymo.com/label-makers-printers/labelwriter-label-printers/dymo-labelwriter-450-direct-thermal-label-printer/SP_95488.html)

- [CUPS](https://ubuntu.com/server/docs/service-cups)

- [Install Dymo LabelWriter on Headless Linux](https://www.baitando.com/it/2017/12/12/install-dymo-labelwriter-on-headless-linux)

- [CUPS Dockerfile](https://github.com/olbat/dockerfiles/tree/master/cupsd)

- [Windows 10 and CUPS](https://techblog.paalijarvi.fi/2020/05/25/making-windows-10-to-print-to-a-cups-printer-over-the-network/)

- [Jonathans Cups Blog](https://johnathan.org/configure-a-raspberry-pi-as-a-print-server-for-dymo-label-printers/)
