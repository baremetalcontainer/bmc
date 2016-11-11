#!/bin/sh
# codisigning wrapper

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

SCRIPT_DIR="${SCRIPT_FILENAME%/*}"
SCRIPT_BASE="${SCRIPT_FILENAME##*/}"
SCRIPT_MAIN="$SCRIPT_DIR/$SCRIPT_BASE-main"

#### check for signing requested
sign=false
QS=""
for KV in $(echo "${QUERY_STRING-}" | tr '&' '\n'); do
	case "$KV" in
	sign=req)	sign=true;;
	sign=*)		sign=false;;
	*)		QS="${QS:+$QS&}$KV";;
	esac
done
#if ! "$sign" && [ "${HTTPS:-off}" = "off" ]; then
if ! "$sign"; then
	exec "$SCRIPT_MAIN"
	exit 1	# when SCRIPT_MAIN doesn't exist.

fi
QUERY_STRING="$QS"

#### ok, run SCRIPT_MAIN and sign.
: "${BMC_CONF:=@BMC_CONF@}"
[ -r "$BMC_CONF" ] || { echo "$0: can not read $BMC_CONF"; exit 1; }
. "${BMC_CONF}"
. "${BMC_SHARE_DIR}/bmc.func"

trap bmc_atexit 0 HUP INT QUIT TERM
bmc_atexit()
{
	trap - 0 # clear exit handler
	bmc_rm_atexit
}

#### exec the script
resp="$(bmc_mktemp)"
bmc_rm_after "$resp"
"$SCRIPT_MAIN" >"$resp"

#### fix cgi parameter sign=no -> sign=req
#NOTE: this process is not needed..
resp1="$(bmc_mktemp)"
bmc_rm_after "$resp1"
$SED -r '/https?:/{s|sign=no|sign=req|;}' "$resp" >"$resp1"
resp="$resp1"

#### cut response body
resp_body="$(bmc_mktemp)"
bmc_rm_after "$resp_body"
$SED '1,/^$/d' "$resp" >"$resp_body"

#### make sign of response body
resp_sig="$(bmc_mktemp)"
bmc_rm_after "$resp_sig"
bmc_codesign "$resp_body" "$resp_sig"

#### put sign
cp "$resp_sig" "$BMC_DIST_ROOT/sig/$REMOTE_ADDR.sig"
#note: $BMC_DIST_ROOT/sig/$REMOTE_ADDR.sig will be gotten via /cgi-bin/bmc-sig

#### finish
cat "$resp"
exit 0
