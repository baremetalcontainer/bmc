#!/bin/sh
set -eu
DIR="$1"
mkdir -p "$DIR"
FILTER()
{
	case "$BMC" in
	/*) sed "s|$BMC|bmc|";;
	*) cat;;
	esac
}
$BMC help | awk '/^Commands:$/{ON=1}; /^$/{ON=0}; ON&&/^ /{print $1}' | while read CMD; do
	TXT="$DIR/$CMD.txt"
	$BMC help "$CMD" | FILTER >"$TXT.tmp" || {
		rm -f "$TXT.tmp"
		echo "XXX NO USAGE" >"$TXT"
		continue
	}
	if [ -f "$TXT" ] && cmp "$TXT" "$TXT.tmp"; then
		rm "$TXT.tmp"
	else
		mv "$TXT.tmp" "$TXT"
	fi
done
exit 0
