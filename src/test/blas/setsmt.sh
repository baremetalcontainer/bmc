#!/bin/sh
# usage: sh setsmt.sh on|off
set -ue

onoff="$1"

#if [ $(lscpu --all --parse=cpu |sort -n|uniq|wc -l) -eq $(lscpu --all --parse=core |sort -n|uniq|wc -l) ]; then
#	echo "WARNING: NOT SMT"
#	exit 0
#fi

lscpucore()
{
	lscpu --all --parse="cpu,core" | grep -v '^#'
}

lsonoff()
{
	case "$onoff" in
	off)
		awk -F, '{printf("%d %d\n", $1, core[$2]?0:1); core[$2]=1;}'
		;;
	on)
		awk -F, '{print $1,1;last=$2}'
		;;
	esac
}

setonline()
{
	${SUDO-} /bin/sh -c '
	while read cpu val; do
		online=/sys/devices/system/cpu/cpu$cpu/online
		if [ -f $online ]; then
			echo $val >$online
		fi
	done
	'
}

lscpucore | lsonoff | setonline
exit 0
