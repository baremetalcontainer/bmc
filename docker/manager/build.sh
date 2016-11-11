#!/bin/sh
set -eux

AMT_PASSWORD="XXX"
MAINTAINER="your@email.addr"

DOCKER="docker"
#DOCKER="sudo docker"
export DOCKER

####################

### Start a BMC server for build
WORKNAME="build-bmc-manager-$$"
cleanup() {
	${DOCKER} rm -f "$WORKNAME"
}
trap cleanup EXIT INT TERM
../run-bmc --detach --name="$WORKNAME"

### Wait for starting docker daemon
while ! ${DOCKER} exec $WORKNAME docker info >/dev/null; do
	sleep 1
done

### Build BMC image (OS part)
${DOCKER} exec --tty $WORKNAME sh -c "mkdir -p /work/bmc/centos7"
${DOCKER} cp Dockerfile.centos7.bmc $WORKNAME:/work/bmc/centos7/Dockerfile
${DOCKER} exec --tty $WORKNAME sh -c "cd /work/bmc/centos7 && ${DOCKER} build --tag=centos7.bmc ."
${DOCKER} exec --tty $WORKNAME sh -c "docker images"
${DOCKER} exec --tty $WORKNAME sh -c "bmc pull --nopull centos7.bmc"
${DOCKER} exec --tty $WORKNAME sh -c "bmc images"

### Pull BMC image (kernel and initrd)
${DOCKER} exec --tty $WORKNAME sh -c "bmc pull-bmc https://github.com/baremetalcontainer/bmc-ubuntu-3.13.11.git default"
${DOCKER} exec --tty $WORKNAME sh -c "bmc images"

### Add a worker node
### !!!YOU SHOULD REWRITE HERE!!! XXX
${DOCKER} exec --tty $WORKNAME sh -c "bmc addnode \
--name='dc3-6' \
--rank=1 \
--method_mgmt=amt \
--descr='Core2Quad Dell Optiplex 960 09AA8199 (5/6)' \
--have_tpm=false \
--ip4_addr_mgmt='172.21.200.36' \
--password_mgmt='$AMT_PASSWORD' \
--ip4_addr_boot='172.21.200.36' \
--interface_os='eth0' \
--ip4_addr_os='172.21.200.36' \
--netmask_os='255.255.255.0' \
--gateway_os='172.21.200.254' \
--dns_os='163.220.2.34' "
${DOCKER} exec --tty $WORKNAME sh -c "bmc nodes"

### Commit
${DOCKER} stop --time=5 $WORKNAME
${DOCKER} commit --author=$MAINTAINER --message="BMC-in-Docker" $WORKNAME bmc-manager
${DOCKER} images bmc-manager

echo "done"
