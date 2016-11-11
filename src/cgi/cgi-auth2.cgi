#!/bin/sh
# WORKAROUND FOR iPXE BUG (die at boot)

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

bmc_id=""
for KV in $(echo "${QUERY_STRING-}" | tr '&' '\n'); do
	case "$KV" in
	bmcid=?*) bmc_id="${KV#bmcid=}";;
	*) ;;
	esac
done

resp="$(bmc_mktemp)"
bmc_rm_after "$resp"
output_response()
{
	bmc_http_resp_header
	cat "$resp"
}

echo_ipxe_timestamp()
{
	local tag="$1"; shift
	local begend="$1"; shift
	[ $# -eq 0 ] || { ERROR "BUG: REST: $*"; exit 1; }
	echo "imgfetch --name timestamp http://${SERVER_ADDR}/${BMC_CGI_PATH}/bmc-debug?${tag}:${begend}_bmcid=${bmc_id}"
	echo "imgfree timestamp"
}

https=https

{
echo "#!ipxe"
echo "imgfree"
echo_ipxe_timestamp load_new_session begin
echo "imgload ${https}://${SERVER_ADDR}/${TPM_CGI_PATH}/${TPM_NEWSESSION_CGI}?mac_addr=\${net0/mac}&bmcid=${bmc_id}&sign=req || goto error"
echo_ipxe_timestamp load_new_session end
echo_ipxe_timestamp verify_new_session begin
echo "imgverify ${TPM_NEWSESSION_CGI} ${https}://${SERVER_ADDR}/${BMC_CGI_PATH}/bmc-sig || goto error1"
echo_ipxe_timestamp verify_new_session end
echo "imgstat"
echo "imgexec ${TPM_NEWSESSION_CGI} || goto error"
echo "echo SOMETHING BAD"
echo "goto error"

echo ":error1"
echo "echo Code Verification failure"
echo ":error"
echo "prompt --key 0x02 --timeout 10000 Press Ctrl-B for the iPXE shell... || goto timeout"
echo "shell"
echo "exit"
echo ":timeout"
echo "poweroff"
echo "reboot"
echo "shell"
} >"$resp"
output_response
exit 0
