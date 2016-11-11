FROM fedora:22

### BMC uses rc.local
RUN echo "#!/bin/sh" >/etc/rc.d/rc.local && ln -s rc.d/rc.local /etc/rc.local

### enable SSH
RUN dnf -y install net-tools openssh-server openssh && dnf clean all
# make place for authorized_keys
RUN mkdir -p /root/.ssh && chmod -R 600 /root/.ssh

#ps
#dnf install -y procps-ng && dnf clean all
#less
#dnf install -y less && dnf clean all
