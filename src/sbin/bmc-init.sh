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

[ ! -f "$BMC_DB" ] || rm -i "$BMC_DB"

: >"$BMC_DB"
chown 0:0 "$BMC_DB"
chmod 644 "$BMC_DB"

SQL "
BEGIN TRANSACTION;
CREATE TABLE Log(
	date		TEXT DEFAULT CURRENT_TIMESTAMP,
	pid		INT,
	message		TEXT
);
CREATE TABLE Node(
	node_id		INTEGER PRIMARY KEY AUTOINCREMENT,
	node_name	TEXT UNIQUE,
	node_descr	TEXT,
	node_rank	INTEGER,
	have_tpm	BOOL,
	method_mgmt	TEXT, -- wol,amt,amt-soap,ipmi
	mac_addr_mgmt	TEXT UNIQUE,
	ip4_addr_mgmt	TEXT UNIQUE,
	password_mgmt	TEXT,
	ip4_addr_boot	TEXT UNIQUE,
	interface_os	TEXT,
	ip4_addr_os	TEXT UNIQUE,
	netmask_os	TEXT,
	gateway_os	TEXT,
	dns_os		TEXT
);
CREATE TABLE Container(
	bmc_id		TEXT PRIMARY KEY,
	base_name	TEXT UNIQUE,
	client_addr	TEXT,
	kernel_id	INTEGER REFERENCES Kernel(kernel_id),
	kernel_param	TEXT,
	initrd_id	INTEGER REFERENCES Initrd(initrd_id),
	rootfs_id	INTEGER REFERENCES Rootfs(rootfs_id),
	fstype		STRING, -- nfs, ramfs, s-ramfs, isofs
	node_id		INTEGER,
	command		TEXT,
	created		TEXT DEFAULT CURRENT_TIMESTAMP,
	state		TEXT DEFAULT 'terminated'
				-- up, pending, running, shutting-down, terminated
);
CREATE TABLE Kernel(
	kernel_id	INTEGER PRIMARY KEY AUTOINCREMENT,
	kernel_name	TEXT UNIQUE,
	kernel_file	TEXT,
	kernel_sig_file	TEXT,
	kernel_param	TEXT
);
CREATE TABLE Initrd(
	initrd_id	INTEGER PRIMARY KEY AUTOINCREMENT,
	initrd_name	TEXT UNIQUE,
	initrd_file	TEXT,
	initrd_sig_file	TEXT
);
CREATE TABLE Rootfs(
	rootfs_id	INTEGER PRIMARY KEY AUTOINCREMENT,
	rootfs_name	TEXT UNIQUE,
	rootfs_file	TEXT,
	rootfs_sig_file	TEXT
);

INSERT INTO Log(message) VALUES('Initialize');
COMMIT TRANSACTION;
"

exit 0
