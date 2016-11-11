FROM jpetazzo/dind:latest
MAINTAINER bmc@aist.go.jp

# Install packages required by BMC
RUN apt update && apt install -y amtterm apache2 etherwake expect gcc git groff ipmitool jq liblzma-dev make mercurial netcat nkf openssl sqlite3 ssh wget wsmancli

# Enable CGI
RUN a2enmod cgid
#ADD files/printenv.cgi /usr/lib/cgi-bin/printenv
#RUN chmod a+x /usr/lib/cgi-bin/printenv

# Enable NFS server
ADD files/etc-exports /etc/exports

# Extract BMC
ADD tmp/bmc.tar.gz /work

# Install BMC
RUN cd /work/bmc/src && make && ./install.sh && /opt/bmc/sbin/bmc-init 
# test
RUN service apache2 start && wget -q -O- http://localhost/cgi-bin/baremetal.ipxe && wget -q -O- "http://localhost/cgi-bin/notify-bmc?bmcid=999&status=xxx"

# Tune for BMC-in-Docker
ENV PATH /opt/bmc/bin:/opt/bmc/sbin:$PATH
ADD files/start-bmc-in-docker.sh /opt/bmc/sbin/start-bmc-in-docker
RUN chmod a+x /opt/bmc/sbin/start-bmc-in-docker
CMD ["wrapdocker", "/opt/bmc/sbin/start-bmc-in-docker"]

# iPXE for BMC
ADD files/bmc-ipxe.patch /work/ipxe
ADD files/bmc.ipxe /work/ipxe
