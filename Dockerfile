ARG MAINTAINER
FROM debian:bookworm-slim

# Install Packages (basic tools, cups, basic drivers, HP drivers)
RUN apt-get update \
  && apt-get install -y \
  git \
  cups \
  wget \
  cups-client \
  usbutils \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# # Add Cups Driver
# RUN apt-get update \
#   && apt-get install -y \
#   printer-driver-dymo \
#   && apt-get clean \
#   && rm -rf /var/lib/apt/lists/*

# RUN apt-get update && apt-get install -y autoconf build-essential libavahi-client-dev \
#   libgnutls28-dev libkrb5-dev libnss-mdns libpam-dev \
#   libsystemd-dev libusb-1.0-0-dev zlib1g-dev git && \
#   git clone --depth 1 --branch v2.4.9 https://github.com/OpenPrinting/cups.git &&\
#   cd cups && \
#   ./configure &&\
#   make && \
#   make install

# Install Dymo CUPS Drivers
RUN wget http://download.dymo.com/dymo/Software/Download%20Drivers/Linux/Download/dymo-cups-drivers-1.4.0.tar.gz &&\
    tar -xzf dymo-cups-drivers-1.4.0.tar.gz &&\
    mkdir -p /usr/share/cups/model &&\
    cp dymo-cups-drivers-1.4.0.5/ppd/ /usr/share/cups/model/

# Install Dymo SDK Patch
RUN cd ~/ &&\
    git clone https://github.com/ScottGibb/DYMO-SDK-for-Linux.git &&\
    cd DYMO-SDK-for-Linux &&\
    aclocal &&\
    automake --add-missing &&\
    autoconf &&\
    ./configure &&\
    make &&\
    make install


# Required for setting the lp admin settings in the next stage
RUN apt-get update && apt-get install -y \
  sudo \
  whois\
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Add user and disable sudo password checking
RUN useradd \
  --groups=sudo,lp,lpadmin \
  --create-home \
  --home-dir=/home/print \
  --shell=/bin/bash \
  --password=$(mkpasswd print) \
  print \
  && sed -i '/%sudo[[:space:]]/ s/ALL[[:space:]]*$/NOPASSWD:ALL/' /etc/sudoers

  # Install Python
RUN apt-get update && apt-get install -y \
python3 \
&& apt-get clean \
&& rm -rf /var/lib/apt/lists/*

WORKDIR /CUPS
# RUN mkdir -p  /usr/share/cups/model
# COPY ppd/ /usr/share/cups/model

# RUN apt-get update && apt-get install -y \
#   printer-driver-dymo \
#   && apt-get clean \
#   && rm -rf /var/lib/apt/lists/*

# Copy the default configuration file
COPY --chown=root:lp conf/cupsd.conf /etc/cups/cupsd.conf
COPY --chown=root:lp conf/cups-files.conf /etc/cups/cups-files.conf

COPY test.txt test.txt

COPY scripts/add_printers.py add_printers.py

EXPOSE 631
# Start Up Scripts
COPY scripts/setup.sh setup.sh
RUN chmod +x setup.sh
# Run CUPS in the foreground
CMD ["./setup.sh"]
