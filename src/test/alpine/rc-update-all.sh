#!/bin/sh
set -eu

cd /etc/init.d
for F in *; do
	case "$F" in
	killprocs) continue;;
	net-online) continue;;
	esac
	if [ "$(head -1 "$F")" != "#!/sbin/openrc-run" ]; then
		continue
	fi
	OK=true
	for D in $(./$F depend | grep '^need'); do
		if [ "$D" = "killprocs" ]; then
			OK=false
			break
		fi
	done
	if "$OK"; then
		rc-update add $F default
	fi
done
