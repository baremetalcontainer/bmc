#!/bin/sh
# poweroff command for BMC
pkill sshd; sleep 1
/sbin/poweroff -f	# just reboot(RB_POWER_OFF). Don't use init
