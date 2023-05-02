FROM raspbian/stretch

# Install dependencies
RUN apt-get update 
RUN apt-get install -y \
    sudo \
    whois \
    usbutils \
    cups \
    cups-client \
    cups-bsd \
    cups-filters \
    foomatic-db-compressed-ppds \
    printer-driver-all \
    openprinting-ppds \
    hpijs-ppds \
    hp-ppd \
    hplip \
    smbclient \
    printer-driver-cups-pdf \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get install -y \
    printer-driver-dymo

RUN wget http://download.dymo.com/dymo/Software/Download%20Drivers/Linux/Download/dymo-cups-drivers-1.4.0.tar.gz &&\
    tar -xzf dymo-cups-drivers-1.4.0.tar.gz &&\
    mkdir -p /usr/share/cups/model &&\
    cp dymo-cups-drivers-1.4.0.5/ppd/lw450.ppd /usr/share/cups/model/ 

# Expose port 631 for CUPS web interface
EXPOSE 631

# Add user and disable sudo password checking
RUN useradd \
    --groups=sudo,lp,lpadmin \
    --create-home \
    --home-dir=/home/print \
    --shell=/bin/bash \
    --password=$(mkpasswd print) \
    print \
    && sed -i '/%sudo[[:space:]]/ s/ALL[[:space:]]*$/NOPASSWD:ALL/' /etc/sudoers

# Copy the default configuration file
COPY --chown=root:lp cupsd.conf /etc/cups/cupsd.conf

COPY ./setup.sh ./setup.sh
RUN chmod +x /setup.sh

# Run CUPS in the foreground
CMD ["./setup.sh"]


