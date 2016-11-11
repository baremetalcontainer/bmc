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

set -eu
: "${BMC_CONF:=@BMC_CONF@}"
[ -r "$BMC_CONF" ] || { echo "$0: can not read $BMC_CONF"; exit 1; }
. "${BMC_CONF}"
. "${BMC_SHARE_DIR}/bmc.func"

#SQLITE3=sqlite3
#set +o posix # for BASH

MODE=tabs

USAGE()
{
	echo "Usage: $0 [-C|-H|-T] [DBfile]"
	echo " -C column mode"
	echo " -H html mode"
	echo " -T tab mode"
}

while getopts 'hCHT' OPT; do
	case "$OPT" in
	h) USAGE; exit 0;;
	C) MODE=column;;
	H) MODE=html;;
	T) MODE=tabs;;
	*) USAGE; exit 1;;
	esac
done
shift $((OPTIND - 1))
case "$#" in
0)	readonly DB="$BMC_DB";;
1)	readonly DB="$1"; shift;;
*)	USAGE; exit 1;;
esac
if [ ! -n "$DB" ]; then
	echo "$0: BMC_DB is not set"
	exit 1
elif [ ! -r "$DB" ]; then
	echo "$0: $DB does not exist"
	exit 1
fi

LIST_TABLES()
{
	# ref:
	# How do I list all tables/indices contained in an SQLite database
	# http://www.sqlite.org/faq.html#q7
	{
		echo ".header off"
		echo ".mode list"
		echo "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;"
	} | $SQLITE3 -batch -bail "$DB"
}

ECHO_HEADER()
{
	case "$MODE" in
	tabs)	echo "== $*";;
	column)	echo "== $*";;
	html)	echo "<H1>$*</H1>";;
	esac
}

ECHO_PRE()
{
	case "$MODE" in
	tabs)	;;
	column)	;;
	html)	echo "<TABLE border=1 cellspacing=0>";;
	esac
}

ECHO_POST()
{
	case "$MODE" in
	tabs)	echo "";;
	column)	echo "";;
	html)	echo "</TABLE>";;
	esac
}

ECHO_POST()
{
	case "$MODE" in
	tabs)	echo "";;
	column) echo "";;
	html)	echo "</TABLE>";;
	esac
}

FILTER()
{
	case "$MODE" in
	tabs)	show_table tbl;;
	column) cat;;
	html)	cat;;
	esac
}

DUMP_TABLE()
{
	ECHO_HEADER "$TABLE"
	ECHO_PRE
	TABLE="$1"
	{
		echo ".header on"
		echo ".nullvalue <NULL>"
		echo ".mode $MODE"
		echo "SELECT * FROM $TABLE;"
	} | $SQLITE3 -batch -bail "$DB" | FILTER
	ECHO_POST
}

DUMP_ALL()
{
	LIST_TABLES | while read TABLE; do
		DUMP_TABLE "$TABLE"
	done
}

case "$MODE" in
column)	DUMP_ALL;;
tabs)	DUMP_ALL;;
html)
	echo "<HTML>"
	DUMP_ALL
	echo "</HTML>"
	;;
esac

exit 0
