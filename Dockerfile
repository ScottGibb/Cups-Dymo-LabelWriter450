ARG MAINTAINER
FROM debian:bookworm-slim

# Install Packages (basic tools, cups, basic drivers, HP drivers)
RUN apt-get update \
  && apt-get install -y \
  git \
  cups \
  cups-client \
  usbutils \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Add Cups Driver
RUN apt-get update \
  && apt-get install -y \
  printer-driver-dymo \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*


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
RUN mkdir -p  /usr/share/cups/model
COPY ppd/ /usr/share/cups/model

# Copy the default configuration file
COPY --chown=root:lp conf/cupsd.conf /etc/cups/cupsd.conf
COPY test.txt test.txt

COPY scripts/add_printers.py add_printers.py

EXPOSE 631
# Start Up Scripts
COPY scripts/setup.sh setup.sh
RUN chmod +x setup.sh
# Run CUPS in the foreground
CMD ["./setup.sh"]
