#!/bin/sh

# Copyright(C): National Institute of Advanced Industrial Science and Technology 2016
# Authors:     
#               Hidetaka Koie <koie-hidetaka@aist.go.jp>
#               Kuniyasu Suzaki <k.suzaki@aist.go.jp>
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# NOTICE: EDIT "etc/bmc.conf" before install.

# Usage
#  ./install.sh -n
#  sudo ./install.sh
#  ./install.sh list
#  sudo ./install.sh [-n] deinstall

set -eu

SRC_BMC_CONF="./etc/bmc.conf"
. "$SRC_BMC_CONF"
BMC_CONF="$BMC_TOP_DIR/etc/bmc.conf"

PROG="$0"
RUN=yes

ROOT="$($AWK -F: '$3==0{print $1;exit}' /etc/passwd)"
WHEEL="$($AWK -F: '$3==0{print $1;exit}' /etc/group)"

MKVERSION()
{
	if hg root >/dev/null 2>&1; then
		REV="$(hg parent --template '{node|short}')"
		MOD=""
		if [ "$(hg status --modified | wc -l)" -gt 0 ]; then
			MOD="+"
		fi
		BMC_VERSION="$REV$MOD"
	elif [ -f VERSION ]; then
		BMC_VERSION="$(cat VERSION)"
	elif [ -f ../.hg_archival.txt ]; then
		BMC_VERSION="$(cat ../.hg_archival.txt | $AWK '/^node:/{print $2}' | head -c12)"
	else
		BMC_VERSION="UNKNOWN"
	fi
}

EXEC()
{
	printf "* %s\n" "$*"
	if [ "$RUN" = yes ]; then
		"$@"
	fi
}

EXECSAFE()
{	printf "* %s?\n" "$*"
	if [ "$RUN" = yes ]; then
		"$@" || true
	fi
}

CKCMD()
{
	local cmd
	$SED -n '/--cmd:begin--/,/--cmd:end--/{/^#/d;p}' "$SRC_BMC_CONF" |
	 $AWK '/bmc_setvar/ {for (i=1; i<10; i++) if ($i=="bmc_setvar") { print $(i+2); next } }' |
	  $SED 's/^"//;s/"$//' |
	   while read cmd; do
		if ! type "$cmd" >/dev/null 2>&1; then
			echo "WARN: \"$cmd\" is not found."
		fi
	done
}

TEMP="$(mktemp)"
trap ATEXIT 0
ATEXIT()
{
	rm -f "$TEMP"
}
SUBST()
{
	local FILE="$1"
	if [ ! -f "$FILE" ]; then
		echo "$FILE"
		return 0
	fi
	if [ "$RUN" = yes ]; then
		sed "s|@BMC_CONF@|$BMC_CONF|g;s|@BMC_VERSION@|$BMC_VERSION|g;s|@BMC_TOOL_DIR@|$BMC_TOOL_DIR|g;s|@LSB@|$LSB|g;" "$FILE" >"$TEMP"
		echo "$TEMP"
	else
		echo "\$(SUBST $FILE)"
	fi
}

INSTALL()
{
	CKCMD
	MKVERSION

	EXEC install -o "$ROOT" -g "$WHEEL" -m 0755 -d "$BMC_BIN_DIR"
	EXEC install -o "$ROOT" -g "$WHEEL" -m 0755 -d "$BMC_SBIN_DIR"
	EXEC install -o "$ROOT" -g "$WHEEL" -m 0755 -d "$BMC_ETC_DIR"
	EXEC install -o "$ROOT" -g "$WHEEL" -m 0755 -d "$BMC_SHARE_DIR"
	EXEC install -o "$ROOT" -g "$WHEEL" -m 0755 -d "$BMC_TOOL_DIR"
	EXEC install -o "$ROOT" -g "$WHEEL" -m 0755 -d "$BMC_DB_DIR"
	EXEC install -o "$ROOT" -g "$WHEEL" -m 0755 -d "$BMC_REPO_ROOT"
	EXEC install -o "$ROOT" -g "$WHEEL" -m 0755 -d "$BMC_REPO_ROOT/kernel"
	EXEC install -o "$ROOT" -g "$WHEEL" -m 0755 -d "$BMC_REPO_ROOT/initrd"
	EXEC install -o "$ROOT" -g "$WHEEL" -m 0755 -d "$BMC_REPO_ROOT/rootfs"
	#EXEC install -o "$ROOT" -g "$WHEEL" -m 0755 -d "$BMC_REPO_ROOT/OLD"
	#EXEC install -o "$ROOT" -g "$WHEEL" -m 0755 -d "$BMC_REPO_ROOT/OLD/kernel"
	#EXEC install -o "$ROOT" -g "$WHEEL" -m 0755 -d "$BMC_REPO_ROOT/OLD/initrd"
	#EXEC install -o "$ROOT" -g "$WHEEL" -m 0755 -d "$BMC_REPO_ROOT/OLD/rootfs"
	EXEC install -o "$ROOT" -g "$WHEEL" -m 0755 -d "$BMC_DIST_ROOT"
	EXEC install -o "$ROOT" -g "$WHEEL" -m 0755 -d "$BMC_DIST_ROOT/kernel"
	EXEC install -o "$ROOT" -g "$WHEEL" -m 0755 -d "$BMC_DIST_ROOT/initrd"
	EXEC install -o "$ROOT" -g "$WHEEL" -m 0755 -d "$BMC_DIST_ROOT/rootfs"
	EXEC install -o "$HTTPD_USER" -g "$HTTPD_GROUP" -m 0755 -d "$BMC_DIST_ROOT/sig"
	EXEC install -o "$ROOT" -g "$WHEEL" -m 0755 -d "$BMC_DISTFS_ROOT"
	EXEC install -o "$ROOT" -g "$WHEEL" -m 1777 -d "$BMC_TMP"
	EXEC install -o "$ROOT" -g "$WHEEL" -m 1733 -d "$BMC_INCOMING"

	EXEC install -o "$ROOT" -g "$WHEEL" -m 644 "$(SUBST etc/bmc.conf)" "$BMC_ETC_DIR/bmc.conf"
	EXEC install -o "$ROOT" -g "$WHEEL" -m 444 "$(SUBST share/bmc.func)" "$BMC_SHARE_DIR/bmc.func"

	EXEC install -o "$ROOT" -g "$WHEEL" -m 555 "$(SUBST bin/bmc.sh )" "$BMC_BIN_DIR/bmc"
	EXEC install -o "$ROOT" -g "$WHEEL" -m 555 "$(SUBST sbin/bmc-init.sh )" "$BMC_SBIN_DIR/bmc-init"
	EXEC install -o "$ROOT" -g "$WHEEL" -m 555 "$(SUBST sbin/bmc-load.sh )" "$BMC_SBIN_DIR/bmc-load"
	EXEC install -o "$ROOT" -g "$WHEEL" -m 555 "$(SUBST sbin/bmc-cleanup.sh )" "$BMC_SBIN_DIR/bmc-cleanup"
	EXEC install -o "$ROOT" -g "$WHEEL" -m 555 "$(SUBST sbin/bmc-dumpdb.sh )" "$BMC_SBIN_DIR/bmc-dumpdb"
	EXEC install -o "$ROOT" -g "$WHEEL" -m 555 "$(SUBST sbin/bmc-sql.sh )" "$BMC_SBIN_DIR/bmc-sql"

	EXEC install -o "$ROOT" -g "$WHEEL" -m 555 "$(SUBST cgi/cgi-with-sign.sh )" "$BMC_CGI_DIR/with-sign"
	EXEC install -o "$ROOT" -g "$WHEEL" -m 555 "$(SUBST cgi/cgi-baremetal.ipxe )" "$BMC_CGI_DIR/baremetal.ipxe-main"
	EXEC ln -f "$BMC_CGI_DIR/with-sign" "$BMC_CGI_DIR/baremetal.ipxe"
	EXEC install -o "$ROOT" -g "$WHEEL" -m 555 "$(SUBST cgi/cgi-notify-bmc.sh )" "$BMC_CGI_DIR/notify-bmc-main"
	EXEC ln -f "$BMC_CGI_DIR/with-sign" "$BMC_CGI_DIR/notify-bmc"
	EXEC install -o "$ROOT" -g "$WHEEL" -m 555 "$(SUBST cgi/cgi-bmc-sig.sh )" "$BMC_CGI_DIR/bmc-sig"
	EXEC install -o "$ROOT" -g "$WHEEL" -m 555 "$(SUBST cgi/cgi-debug.sh )" "$BMC_CGI_DIR/bmc-debug"

	EXEC install -o "$ROOT" -g "$WHEEL" -m 555 "$(SUBST cgi/cgi-auth2.cgi )" "$BMC_CGI_DIR/auth2.cgi-main"
	EXEC ln -f "$BMC_CGI_DIR/with-sign" "$BMC_CGI_DIR/auth2.cgi"

	if [ ! -f "$CODESIGN_PASS" ]; then
	EXEC install -o "$ROOT" -g "$WHEEL" -m 0755 -d "$CODESIGN_DIR"
	EXEC install -o "$ROOT" -g "$WHEEL" -m 0755 -d "$CODESIGN_CA_DIR"
	EXEC install -o "$HTTPD_USER" -g "$HTTPD_GROUP" -m 400 /dev/null "$CODESIGN_PASS"
	fi

	if [ ! -f "$BMC_TIME_FILE" ]; then
	EXEC install -o "$ROOT" -g "$WHEEL" -m 666 /dev/null "$BMC_TIME_FILE"
	fi

	EXECSAFE install -o "$ROOT" -g "$WHEEL" -m 555 "$(SUBST tool/mkchart.sh)" "$BMC_TOOL_DIR/mkchart"
	EXECSAFE install -o "$ROOT" -g "$WHEEL" -m 555 "$(SUBST tool/sarnet.sh)" "$BMC_TOOL_DIR/sarnet"
	EXECSAFE install -o "$ROOT" -g "$WHEEL" -m 555 "$(SUBST tool/joule.sh)" "$BMC_TOOL_DIR/joule"
	EXECSAFE install -o "$ROOT" -g "$WHEEL" -m 555 "$(SUBST tool/killall.sh)" "$BMC_TOOL_DIR/bmckillall"
	EXECSAFE install -o "$ROOT" -g "$WHEEL" -m 555 "$(SUBST tool/mkman.sh)" "$BMC_TOOL_DIR/mkman"
	EXECSAFE install -o "$ROOT" -g "$WHEEL" -m 555 "$(SUBST tool/plotdmesg.sh)" "$BMC_TOOL_DIR/plotdmesg"
	EXECSAFE install -o "$ROOT" -g "$WHEEL" -m 555 "$(SUBST tool/bmc-push.sh)" "$BMC_TOOL_DIR/bmc-push"
	EXECSAFE install -o "$ROOT" -g "$WHEEL" -m 555 "$(SUBST tool/bmc-get-image.sh)" "$BMC_TOOL_DIR/bmc-get-image"
	EXECSAFE install -o "$ROOT" -g "$WHEEL" -m 555 "$(SUBST tool/bmc-copy.sh)" "$BMC_TOOL_DIR/bmc-copy"
	EXECSAFE install -o "$ROOT" -g "$WHEEL" -m 555 "tool/wattchecker" "$BMC_TOOL_DIR/wattchecker"
	EXECSAFE install -o "$ROOT" -g "$WHEEL" -m 555 "tool/setpgid" "$BMC_TOOL_DIR/setpgid"
}
LIST()
{
	set +e
	EXEC ls -lR "$BMC_TOP_DIR"
	EXEC ls -lR "$BMC_BIN_DIR"
	EXEC ls -lR "$BMC_SBIN_DIR"
	EXEC ls -lR "$BMC_ETC_DIR"
	EXEC ls -lR "$BMC_SHARE_DIR"
	EXEC ls -lR "$BMC_DB_DIR"
	EXEC ls -lR "$BMC_REPO_ROOT"
	EXEC ls -lR "$BMC_DIST_ROOT"
	EXEC ls -lR "$BMC_DISTFS_ROOT"
	EXEC ls -lR "$BMC_TMP"
	EXEC ls -lR "$BMC_INCOMING"
	EXEC ls -lR "$BMC_TIME_FILE"
}
DEINSTALL()
{
	set +e
	EXEC rm -rf "$BMC_TOP_DIR"
	EXEC rm -rf "$BMC_BIN_DIR"
	EXEC rm -rf "$BMC_SBIN_DIR"
	EXEC rm -rf "$BMC_ETC_DIR"
	EXEC rm -rf "$BMC_SHARE_DIR"
	EXEC rm -rf "$BMC_DB_DIR"
	EXEC rm -rf "$BMC_REPO_ROOT"
	EXEC rm -rf "$BMC_DIST_ROOT"
	EXEC rm -rf "$BMC_DISTFS_ROOT"
	EXEC rm -rf "$BMC_TMP"
	EXEC rm -rf "$BMC_INCOMING"
	EXEC rm -rf "$BMC_TIME_FILE"
}

#### MAIN ####

while getopts 'n' OPT; do
	case "$OPT" in
	n)	RUN=no ;;
	*)	echo "$PROG: invalid option -$OPT"
		exit 1
		;;
	esac
done
shift $((OPTIND - 1))
case "${1:-install}" in
install)
	INSTALL
	;;
list)
	LIST 2>&1
	;;
erase|deinstall)
	DEINSTALL
	;;
*)
	echo "$0: invalid argument: $*"
	exit 1
	;;
esac

exit 0
