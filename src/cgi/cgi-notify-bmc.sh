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

timestamp "cgi-notify-bmc:begin ${QUERY_STRING-} from ${REMOTE_ADDR}"

ERROR_EXIT()
{
	timestamp "cgi-notify-bmc $*"
	bmc_http_resp_header
	echo "#!ipxe"
	echo "echo BMC: $*"
	exit 0
}

bmcid=""
status=""
for KV in $(echo "${QUERY_STRING-}" | tr '&' '\n'); do
	case "$KV" in
	sign=*) ;;
	bmcid=?*) bmcid="${KV#bmcid=}";;
	status=?*) status="${KV#status=}";; 
	*) ERROR_EXIT "Invalid parameter: $KV" ;;
	esac
done

if [ -z "$bmcid" ]; then
	ERROR_EXIT "No bmcid parameter"
fi
if [ -z "$status" ]; then
	ERROR_EXIT "No status parameter"
fi

timestamp "cgi-notify-bmc bmcid=$bmcid status=$status"

ip4_addr_os="$(db_get_container "$bmcid" ip4_addr_os)"
if [ "${REMOTE_ADDR}" != "$ip4_addr_os" ]; then
	ip4_addr_mgmt="$(db_get_container "$bmcid" ip4_addr_mgmt)"
	ip4_addr_boot="$(db_get_container "$bmcid" ip4_addr_boot)"
	if [ "${REMOTE_ADDR}" != "$ip4_addr_mgmt" -a "${REMOTE_ADDR}" != "$ip4_addr_boot" ]; then
		ERROR_EXIT "Request from Bad address $REMOTE_ADDR"
	fi
fi

rm -f "$BMC_INCOMING/up-$bmcid" 2>&1
echo "$status" >"$BMC_INCOMING/status-$bmcid"

bmc_http_resp_header

timestamp "cgi-notify-bmc:end"
exit 0
