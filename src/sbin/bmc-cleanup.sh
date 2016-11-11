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

yesno()
{
	local YN
	read -p "$* " YN
	case "$YN" in
	[Yy]|YES|Yes|yes) return 0;;
	*) return 1;;
	esac
}

for VAR in BMC_INCOMING BMC_TMP BMC_DISTFS_ROOT BMC_DIST_ROOT BMC_REPO_ROOT; do
	eval DIR=\$$VAR
	if [ ! -d "$DIR" -o "$(find "$DIR" -mindepth 1 -type f -print | wc -l)" -eq 0 ]; then
		echo "Skip: $VAR($DIR) is emtpy."
		continue
	fi
	find "$DIR" -mindepth 1 -type f -ls | $SED 's/^/    /'
	if yesno "Clear $VAR($DIR)?"; then
		printf "Erase: %s... " "$VAR($DIR)"
		find "$DIR" -mindepth 1 -type f -print -delete || true
		printf "done\n"
	fi
done

if [ -f "$BMC_DB" ]; then
	if yesno "Clear BMC_DB($BMC_DB)?"; then
		rm -f "$BMC_DB"
		"$BMC_SBIN_DIR/bmc-init"
	fi
fi

exit 0
