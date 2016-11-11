#!/bin/sh

# NOTICE: THIS IS AN EXAMPLE.

set -eu
: "${BMC_CONF:=@BMC_CONF@}"
[ -r "$BMC_CONF" ] || { echo "$0: can not read $BMC_CONF"; exit 1; }
. "${BMC_CONF}"
BMC="$BMC_BIN_DIR/bmc"

#test "$(id -u)" != 0 || {
#	echo "Don't sudo $0${*+ $*}"
#	exit 1
#}

set -x

#$BMC addnode \
#	--name="node1.com" \
#	--descr="worker node 1" \
#	--rank="1" \
#	--method_mgmt="wol" \
#	--mac_addr_mgmt="01:02:03:04:05:06" \
#	--ip4_addr_mgmt="" \
#	--password_mgmt="" \
#	--ip4_addr_boot="10.1.1.9" \
#	--interface_os="eth0" \
#	--ip4_addr_os="10.1.1.9" \
#	--netmask_os="255.255.0.0" \
#	--gateway_os="10.1.1.254" \
#	--dns_os="10.1.1.1"

#$BMC addnode \
#	--name="node2.com" \
#	--descr="worker node 2" \
#	--rank="2" \
#	--have-tpm="false" \
#	--method_mgmt="amt" \
#	--mac_addr_mgmt="11:12:13:14:15:16" \
#	--ip4_addr_mgmt="10.1.1.99" \
#	--password_mgmt="amtpassword" \
#	--password_mgmt="" \
#	--ip4_addr_boot="10.1.1.99" \
#	--interface_os="eth0" \
#	--ip4_addr_os="10.1.1.99" \
#	--netmask_os="255.255.0.0" \
#	--gateway_os="10.1.1.254" \
#	--dns_os="10.1.1.1"

#$BMC import-kernel default "$HOME/tmp/default-kernel"
#$BMC import-initrd default "$HOME/tmp/default-initrd.img"
#$BMC set-kernel-param default "xxx=yyy"

#$BMC import-kernel memdisk "$HOME/tmp/memdisk"
#$BMC import-initrd mfsbsd "$HOME/tmp/mfsbsd.iso"

#$BMC pull-bmc ssh://hg@bitbucket.org/username/bmc1 default1  # hg
#$BMC pull-bmc git@bitbucket.org:username/bmc2.git  default2  # git

exit 0
