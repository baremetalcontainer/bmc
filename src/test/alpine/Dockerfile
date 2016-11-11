FROM alpine:3.4

# Install OpenRC invoked by /sbin/init+/etc/inittab
RUN apk add --no-cache openrc

# Setup SSH server
RUN apk add --no-cache openssh
#RUN rc-update --update add sshd

## Replace poweroff command
#COPY poweroff.sh /usr/local/sbin/poweroff
#RUN chmod a+x /usr/local/sbin/poweroff

# /etc/rc.local is invoked by /etc/local.d/local.start is invoked by /etc/init.d/local
COPY local.start /etc/local.d/local.start
COPY rc.local /etc/rc.local
COPY rc.verbose /etc/conf.d/local
RUN chmod a+x /etc/local.d/local.start /etc/rc.local
#RUN rc-update --update add local default

## Patch: reading /sys/class/net/eth1/carrier causes EINVAL.
#RUN sed -i.orig 's| $x | "$x" |' /etc/init.d/net-online

# Register all scripts
COPY rc-update-all.sh /tmp/rc-update-all.sh
RUN sh /tmp/rc-update-all.sh

## clear root's password (for debugging)
#RUN passwd -d root
