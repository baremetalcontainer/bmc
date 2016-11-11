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

sigfile="$BMC_DIST_ROOT/sig/${REMOTE_ADDR}.sig"
if [ -f "$sigfile" ]; then
	bmc_http_resp_header
	cat "$sigfile"
	rm -f "$sigfile"
else
	echo "Status: 403 Forbidden"
	echo "Content-Type: text/plain"
	echo "Connection: close"
	echo "Pragma: no-cache"
	echo "Cache-Control: no-cache"
	echo ""
	cat "no ${REMOTE_ADDR}.sig"
fi

exit 0
