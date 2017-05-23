#!/bin/sh
# Bare Metal Container

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
[ -r "$BMC_CONF" ] || { echo "$0: can not read $BMC_CONF" 1>&2; exit 1; }
. "${BMC_CONF}"
. "${BMC_SHARE_DIR}/bmc.func"

readonly myprog="$0"

set_start_time
BMC_TRAPS="HUP INT QUIT TERM"
trap bmc_interrupted $BMC_TRAPS
trap bmc_atexit 0
bmc_interrupted()
{
	local status=$?
	INFO "Interrupted"
	bmc_term "$status"
}
bmc_atexit()
{
	bmc_term "$?"
}
BMC_UNDO=""
bmc_term()
{
	local status=$?
	trap "" 0 $BMC_TRAPS # discard any traps on exitting..
	timestamp "atexit-undo:begin"
	if [ -n "$BMC_UNDO" ]; then
		INFO "Rollback: $BMC_UNDO"
		eval "$BMC_UNDO"
	fi
	timestamp "atexit-undo:end"
	timestamp "atexit-rm:begin"
	bmc_rm_atexit
	timestamp "atexit-rm:end"
	timestamp "--End--"
	if [ "$status" -ne 0 ]; then
		ERROR "BMC: failed"
	fi
	exit $status
}
bmc_push_undo()
{
	BMC_UNDO="$*${BMC_UNDO:+ ;:; $BMC_UNDO}"
}
bmc_success()
{
	BMC_UNDO=""
}

######################################################################
INVALID_OPTION()
{
	case "$1" in
	--*)
		local opt="$1"
		local optarg="$2"
		ERROR "Invalid option: $opt${optarg:+=}$optarg"
		exit 1
		;;
	*)
		ERROR "Invalid option: $*"
		exit 1
		;;
	esac
	return 0
}

parse_options()
{
	local proc_opt="$1"; shift
	local parser2="$1"; shift
	while [ $# -gt 0 ]; do
		local arg1="$1"
		local opt
		local optarg
		local nshift=1
		case "$arg1" in
		--*=)
			opt="$(expr "$arg1" : '\(--[^=]*\)=.*')"
			optarg=""
			;;
		--*=*)
			opt="$(expr "$arg1" : '\(--[^=]*\)=.*')"
			optarg="$(expr "$arg1" : '--[^=]*=\(.*\)')"
			;;
		--*)
			opt="$arg1"
			optarg=""
			;;
		-?)
			opt="$arg1"
			if [ "${2+YES}" = YES ]; then
				optarg="$2"
				nshift=2
			else
				optarg=""
			fi
			;;
		-*)
			ERROR "Invalid option: $arg1"
			exit 1
			;;
		*)
			break
			;;
		esac
		shift
		$proc_opt "$opt" "$optarg" || {
			case "$?" in
			1) return 1;;
			2) shift $((nshift - 1));;
			esac
		}
	done
	$parser2 "$@"
	return 0
}

######################################################################
opt_table_fmt="tbl"	# tbl, tsv

######################################################################
usage_XXX()
{
	echo "Usage: $myprog XXX [OPTIONS] XXX"
}

exec_XXX()
{
	timestamp "exec_XXX $*"
	echo "XXX BMC XXX $*"
}

proc_XXX()
{
	local opt="$1"
	local optarg="$2"
	case "$opt" in
	-h|--help)
		usage_XXX
		exit 0
		;;
	*)	INVALID_OPTION "$@"
		;;
	esac
	return 0
}

cmd_XXX()
{
	parse_options proc_XXX exec_XXX "$@"
}

######################################################################
usage_logs()
{
	echo "Usage: $myprog logs [OPTIONS]
  --tsv		Show in Tab-Separated Values"
}

exec_logs()
{
	timestamp "exec_logs:begin $*"
	if [ $# -ne 0 ]; then
		usage_logs
		exit 1
	fi

	{
	echo ".mode tabs"
	echo ".header on"
	echo "SELECT * FROM Log;"
	} | SQL | show_table "$opt_table_fmt"
	timestamp "exec_logs:end $*"
}

proc_logs()
{
	local opt="$1"
	local optarg="$2"
	case "$opt" in
	--tsv)
		opt_table_fmt="tsv"
		;;
	-h|--help)
		usage_logs
		exit 0
		;;
	*)	INVALID_OPTION "$@"
		;;
	esac
	return 0
}

cmd_logs()
{
	parse_options proc_logs exec_logs "$@"
}

######################################################################
usage_addnode()
{
	echo "\
Usage: $myprog addnode --name=NAME --rank=RANK --method_mgmt={wol|amt|amt-soap|ipmi}
	[--descr='TEXT'] [--have_tpm={true|false}]
	[--mac_addr_mgmt=xxx] [--ip4_addr_mgmt=xxx] [--password_mgmt=xxx]
	[--ip4_addr_boot=xxx] [--interface_os=xxx] [--ip4_addr_os=xxx]
	[--netmask_os=xxx] [--gateway_os=xxx] [--dns_os=xxx]"
}

exec_addnode()
{
	timestamp "exec_addnode:begin $*"
	if [ $# -ne 0 ]; then
		usage_addnode
		exit 1
	fi
	if [ -z "$opt_addnode_name" ]; then
		ERROR "name must be specified"
		exit 1
	fi
	if [ -z "$opt_addnode_rank" ]; then
		ERROR "rank must be specified"
		exit 1
	fi
	if [ -z "$opt_addnode_method_mgmt" ]; then
		ERROR "method_mgmt must be specified"
		exit 1
	fi
	case "$opt_addnode_have_tpm" in
	true)	opt_addnode_have_tpm="1";;	# SQLite doesn't have TRUE.
	false)	opt_addnode_have_tpm="0";;	# SQLite doesn't have FALSE.
	*)	ERROR "have_tpm must be true|false"
		exit 1
		;;
	esac
	case "$opt_addnode_method_mgmt" in
	wol|amt|amt-soap|ipmi) ;;
	*)	ERROR "method_mgmt must be wol|amt|amt-soap|ipmi"
		exit 1
		;;
	esac

	if [ "$(db_count Node node_name "$opt_addnode_name")" -ne 0 ]; then
		ERROR "$opt_addnode_name is already registered"
		exit 1
	fi

	SQLwrite "
	BEGIN TRANSACTION;
	INSERT INTO Node(node_name, node_descr, node_rank, have_tpm, method_mgmt, mac_addr_mgmt, ip4_addr_mgmt, password_mgmt, ip4_addr_boot, interface_os, ip4_addr_os, netmask_os, gateway_os, dns_os)
	VALUES(	$(sqlquote "$opt_addnode_name"),
		$(sqlquote "$opt_addnode_descr"),
		$(sqlquote "$opt_addnode_rank"),
		$opt_addnode_have_tpm,
		$(sqlquote "$opt_addnode_method_mgmt"),
		$(sqlquote "$opt_addnode_mac_addr_mgmt"),
		$(sqlquote "$opt_addnode_ip4_addr_mgmt"),
		$(sqlquote "$opt_addnode_password_mgmt"),
		$(sqlquote "$opt_addnode_ip4_addr_boot"),
		$(sqlquote "$opt_addnode_interface_os"),
		$(sqlquote "$opt_addnode_ip4_addr_os"),
		$(sqlquote "$opt_addnode_netmask_os"),
		$(sqlquote "$opt_addnode_gateway_os"),
		$(sqlquote "$opt_addnode_dns_os"));
	COMMIT TRANSACTION;"
	bmc_log "addnode $opt_addnode_name"
	timestamp "exec_addnode:end $*"
}

proc_addnode()
{
	local opt="$1"
	local optarg="$2"
	case "$opt" in
	--name)			opt_addnode_name="$optarg";;
	--descr)		opt_addnode_descr="$optarg";;
	--rank)			opt_addnode_rank="$optarg";;
	--have[-_]tpm)		opt_addnode_have_tpm="$optarg";;
	--method[-_]mgmt)		opt_addnode_method_mgmt="$optarg";;
	--mac[-_]addr[-_]mgmt)	opt_addnode_mac_addr_mgmt="$optarg";;
	--ip4[-_]addr[-_]mgmt)	opt_addnode_ip4_addr_mgmt="$optarg";;
	--password[-_]mgmt)	opt_addnode_password_mgmt="$optarg";;
	--ip4[-_]addr[-_]boot)	opt_addnode_ip4_addr_boot="$optarg";;
	--interface[-_]os)		opt_addnode_interface_os="$optarg";;
	--ip4[-_]addr[-_]os)		opt_addnode_ip4_addr_os="$optarg";;
	--netmask[-_]os)		opt_addnode_netmask_os="$optarg";;
	--gateway[-_]os)		opt_addnode_gateway_os="$optarg";;
	--dns[-_]os)		opt_addnode_dns_os="$optarg";;
	-h|--help)
		usage_addnode
		exit 0
		;;
	*)	INVALID_OPTION "$@"
		;;
	esac
	return 0
}

cmd_addnode()
{
	opt_addnode_name=""
	opt_addnode_descr=""
	opt_addnode_rank=""
	opt_addnode_have_tpm="false"
	opt_addnode_method_mgmt=""
	opt_addnode_mac_addr_mgmt=""
	opt_addnode_ip4_addr_mgmt=""
	opt_addnode_password_mgmt=""
	opt_addnode_ip4_addr_boot=""
	opt_addnode_interface_os=""
	opt_addnode_ip4_addr_os=""
	opt_addnode_netmask_os=""
	opt_addnode_gateway_os=""
	opt_addnode_dns_os=""
	parse_options proc_addnode exec_addnode "$@"
}

######################################################################
usage_delnode()
{
	echo "Usage: $myprog delnode --name=NAME"
}

exec_delnode()
{
	timestamp "exec_delnode:begin $*"
	if [ $# -ne 0 ]; then
		usage_delnode
		exit 1
	fi
	if [ -z "$opt_delnode_name" ]; then
		ERROR "name must be specified"
		exit 1
	fi

	SQLwrite "
	BEGIN TRANSACTION;
	DELETE FROM Node
	WHERE node_name = '$opt_delnode_name' AND
	      node_id NOT IN (SELECT node_id FROM Container);
	COMMIT TRANSACTION;
	"
	bmc_log "delnode $opt_delnode_name"
	timestamp "exec_delnode:end $*"
}

proc_delnode()
{
	local opt="$1"
	local optarg="$2"
	case "$opt" in
	--name)			opt_delnode_name="$optarg";;
	-h|--help)
		usage_delnode
		exit 0
		;;
	*)	INVALID_OPTION "$@"
		;;
	esac
	return 0
}

cmd_delnode()
{
	opt_delnode_name=""
	parse_options proc_delnode exec_delnode "$@"
}

######################################################################
usage_nodes()
{
	echo "Usage: $myprog nodes [OPTIONS]
  --tsv		Show in Tab-Separated Values"
}

exec_nodes()
{
	timestamp "exec_nodes:begin $*"
	if [ $# -ne 0 ]; then
		usage_nodes
		exit 1
	fi

	{
	echo ".mode tabs"
	echo ".header on"
	echo "SELECT
		Node.node_id	ID,
		node_name	name,
		node_descr	descr,
		node_rank	rank,
		have_tpm	tpm,
		method_mgmt	method,
		ip4_addr_mgmt	addr_mgmt,
		ip4_addr_boot	addr_boot,
		interface_os	iface_os,
		ip4_addr_os	addr_os,
		netmask_os	netmask_os,
		gateway_os	gateway_os,
		dns_os		dns_os,
		Container.bmc_id,
		Container.state
		FROM Node
		LEFT OUTER JOIN Container ON Node.node_id = Container.node_id;"
	} | SQL | show_table "$opt_table_fmt"
	timestamp "exec_nodes:end $*"
}

proc_nodes()
{
	local opt="$1"
	local optarg="$2"
	case "$opt" in
	--tsv)
		opt_table_fmt="tsv"
		;;
	-h|--help)
		usage_nodes
		exit 0
		;;
	*)	INVALID_OPTION "$@"
		;;
	esac
	return 0
}

cmd_nodes()
{
	parse_options proc_nodes exec_nodes "$@"
}

######################################################################
usage_import_kernel()
{
	echo "Usage: $myprog import-kernel [OPTIONS] NAME FILE|URL
  -s|--sign=FILE	sign file"
}
usage_import_initrd()
{
	echo "Usage: $myprog import-initrd [OPTIONS] NAME FILE|URL
  -s|--sign=FILE	sign file"
}
usage_import_rootfs()
{
	echo "Usage: $myprog import-rootfs [OPTIONS] NAME FILE|URL"
}
usage_import_bootimage()
{
	usage_import_kernel
	usage_import_initrd
	usage_import_rootfs
}

move_file()
{
	local src="$1"; shift
	local dst="$1"; shift
	[ $# -eq 0 ] || { ERROR "BUG: REST: $*"; exit 1; }

	if [ ! -f "$src" ]; then
		ERROR "$src doesn't exist"
		exit 1
	fi
	SUDO mkdir -p -m 0755 "$(dirname "$dst")"
	SUDO mv -f "$src" "$dst"
}

opt_import_sign=""
exec_import_bootimage()
{
	timestamp "exec_import_bootimage:begin $*"
	if [ $# -ne 3 ]; then
		usage_import_bootimage
		exit 1
	fi
	local name; name="$1"; shift
	local file; file="$1"; shift
	local key; key="$1"; shift
	[ $# -eq 0 ] || { ERROR "BUG: REST: $*"; exit 1; }

	case "$key" in
	kernel|initrd|rootfs) ;;
	*) ERROR "BUG: $key"; exit 1;;
	esac

	local Table="$key"
	local col_name="${key}_name"
	local col_file="${key}_file"
	local col_sig_file="${key}_sig_file"

	local registered; registered="$(db_count "$Table" "$col_name" "$name")"

	#local ofile
	#local old_file_list=""

	local id; id="$(new_id)"
	local repofile; repofile="$key/$name-$id"
	local srcfile
	case "$file" in
	http://*|https://*)
		srcfile="$(bmc_mktemp)"
		bmc_rm_after "$srcfile"
		$WGET --output-document="$srcfile" "$file"
		;;
	*)
		srcfile="$file"
		;;
	esac
	SUDO cp "$srcfile" "$BMC_REPO_ROOT/$repofile"
	#ofile="$(db_get "$Table" "$col_file" "$col_name" "$name")"
	#old_file_list="$old_file_list $ofile"
	#if [ "$key" = "rootfs" ]; then
	#	old_file_list="$old_file_list $ofile-etc";;
	#fi

	local reposigfile=""
	if [ -n "$opt_import_sign" ]; then
		reposigfile="$key/$name-sig-$id"
		SUDO cp "$opt_import_sign" "$BMC_REPO_ROOT/$reposigfile"
		#old_file_list="$old_file_list $(db_get "$Table" "$col_sig_file" "$col_name" "$name")"
	fi

	## repack /etc
	case "$key" in
	rootfs)
		local tmpdir; tmpdir="$(bmc_mktempdir)"
		bmc_rm_after "root@$tmpdir"
		SUDO $GNUTAR -x -z -f "$srcfile" -C "$tmpdir" "$(check_archive_prefix "$srcfile")"etc
		SUDO $GNUTAR -c -z -f "$BMC_REPO_ROOT/$repofile-etc" -C "$tmpdir" etc
		;;
	esac

	if [ "$registered" -eq 0 ]; then
		SQLwrite "
		BEGIN TRANSACTION;
		INSERT INTO $Table($col_name, $col_file, $col_sig_file) values('$name', '$repofile', '$reposigfile');
		COMMIT TRANSACTION;
		"
		case "$key" in
		kernel) exec_set_kernel_param "$name" "" ;;
		esac
		bmc_log "import_$key $name"
	else
		SQLwrite "
		BEGIN TRANSACTION;
		UPDATE $Table SET $col_file = '$repofile', $col_sig_file = '$reposigfile' WHERE $col_name = '$name';
		COMMIT TRANSACTION;
		"
		bmc_log "import_$key $name (update)"
	fi
	#for ofile in $old_file_list; do
	#	move_file "$BMC_REPO_ROOT/$ofile" "$BMC_REPO_ROOT/OLD/$ofile"
	#done
	timestamp "exec_import_bootimage:end $*"
}

proc_import_bootimage()
{
	local opt="$1"
	local optarg="$2"
	case "$opt" in
	-s|--sign)
		opt_import_sign="$optarg"
		return 2
		;;
	-h|--help)
		usage_import_bootimage
		exit 0
		;;
	*)	invalid_option "$@"
		;;
	esac
	return 0
}

cmd_import_kernel()
{
	parse_options proc_import_bootimage exec_import_bootimage "$@" kernel
}
cmd_import_initrd()
{
	parse_options proc_import_bootimage exec_import_bootimage "$@" initrd
}
cmd_import_rootfs()
{
	parse_options proc_import_bootimage exec_import_bootimage "$@" rootfs
}

######################################################################

opt_image_info_list="kernel initrd rootfs"
usage_image_info()
{
	echo "Usage: $myprog image-info [OPTIONS] NAME
  --kernel	kernel only
  --initrd	initrd only
  --rootfs	rootfs only
"
}

exec_image_info()
{
	timestamp "exec_image_info:begin $*"
	if [ $# -ne 1 ]; then
		usage_image_info
		exit 1
	fi
	local name="$1"

	local found=false
	local tbl n
	for tbl in $opt_image_info_list; do
		n="$(echo "SELECT COUNT(*) FROM $tbl WHERE ${tbl}_name = '$name';" | SQL)"
		case "$n" in
		0)	echo "$name does not exist in $tbl";;
		1)	echo "$name exists in $tbl"; found=true;;
		*)	ERROR "DB broken:$name: n=$n"; exit 1;;
		esac
	done

	timestamp "exec_image_info:end $*"

	"$found" || exit 1
}

proc_image_info()
{
	local opt="$1"
	local optarg="$2"
	case "$opt" in
	-h|--help)
		usage_image_info
		exit 0
		;;
	--kernel) opt_image_info_list="kernel";;
	--initrd) opt_image_info_list="initrd";;
	--rootfs) opt_image_info_list="rootfs";;
	*)	INVALID_OPTION "$@"
		;;
	esac
	return 0
}

cmd_image_info()
{
	parse_options proc_image_info exec_image_info "$@"
}

######################################################################

usage_rm_kernel()
{
	echo "Usage: $myprog rm-kernel [OPTIONS] NAME"
}
usage_rm_initrd()
{
	echo "Usage: $myprog rm-initrd [OPTIONS] NAME"
}
usage_rm_rootfs()
{
	echo "Usage: $myprog rm-rootfs [OPTIONS] NAME"
}
usage_rm_bootimage()
{
	usage_rm_kernel
	usage_rm_initrd
	usage_rm_rootfs
}

exec_rm_bootimage()
{
	timestamp "exec_rm_bootimage:begin $*"
	if [ $# -ne 2 ]; then
		usage_import_bootimage
		exit 1
	fi
	local name; name="$1"; shift
	local key; key="$1"; shift
	[ $# -eq 0 ] || { ERROR "BUG: REST: $*"; exit 1; }

	case "$key" in
	kernel|initrd|rootfs) ;;
	*) ERROR "BUG: $key"; exit 1;;
	esac

	local Table="$key"
	local col_name="${key}_name"
	local col_file="${key}_file"
	local col_sig_file="${key}_sig_file"

	if [ "$(db_count "$Table" "$col_name" "$name")" -eq 0 ]; then
		ERROR "$name doesn't exist in $Table"
		exit 1
	fi

	local file; file="$(db_get "$Table" "$col_file" "$col_name" "$name")"
	local sigfile; sigfile="$(db_get "$Table" "$col_sig_file" "$col_name" "$name")"

	SQLwrite "
	BEGIN TRANSACTION;
	DELETE FROM $Table WHERE $col_name = '$name';
	COMMIT TRANSACTION;
	"

	#if [ -n "$file" ]; then
	#	move_file "$BMC_REPO_ROOT/$file" "$BMC_REPO_ROOT/OLD/$file"
	#	if [ "$key" = "rootfs" ]; then
	#		move_file "$BMC_REPO_ROOT/$file-etc" "$BMC_REPO_ROOT/OLD/$file-etc"
	#	fi
	#fi
	#if [ -n "$sigfile" ]; then
	#	move_file "$BMC_REPO_ROOT/$sigfile" "$BMC_REPO_ROOT/OLD/$sigfile"
	#fi

	bmc_log "rm_$key $name"
	timestamp "exec_rm_bootimage:end $*"
}

proc_rm_bootimage()
{
	local opt="$1"
	local optarg="$2"
	case "$opt" in
	-h|--help)
		usage_rm_bootimage
		exit 0
		;;
	*)	INVALID_OPTION "$@"
		;;
	esac
	return 0
}

cmd_rm_kernel()
{
	parse_options proc_rm_bootimage exec_rm_bootimage "$@" kernel
}
cmd_rm_initrd()
{
	parse_options proc_rm_bootimage exec_rm_bootimage "$@" initrd
}
cmd_rm_rootfs()
{
	parse_options proc_rm_bootimage exec_rm_bootimage "$@" rootfs
}

######################################################################

usage_rm_image()
{
	echo "Usage: $myprog rm-image [OPTIONS] NAME"
}

exec_rm_image()
{
	timestamp "exec_rm_image:begin $*"
	if [ $# -ne 1 ]; then
		usage_rm_image
		exit 1
	fi
	local name="$1"

	exec_rm_bootimage "$name" rootfs


	timestamp "exec_rm_image:end $*"
}

proc_rm_image()
{
	local opt="$1"
	local optarg="$2"
	case "$opt" in
	-h|--help)
		usage_rm_image
		exit 0
		;;
	*)	INVALID_OPTION "$@"
		;;
	esac
	return 0
}

cmd_rm_image()
{
	parse_options proc_rm_image exec_rm_image "$@"
}

######################################################################
usage_set_kernel_param()
{
	echo "Usage: $myprog set-kernel-param [OPTIONS] NAME PARAMETERS.."
}

exec_set_kernel_param()
{
	timestamp "exec_set_kernel_param:begin $*"
	if [ $# -lt 2 ]; then
		usage_set_kernel_param
		exit 1
	fi
	local name="$1"; shift
	local parameters="$*"

	if [ "$(db_count Kernel kernel_name "$name")" -eq 0 ]; then
		ERROR "$name doesn't exist"
		exit 1
	fi

	SQLwrite "
	BEGIN TRANSACTION;
	UPDATE Kernel SET kernel_param = '$parameters'
	WHERE kernel_name = '$name';
	COMMIT TRANSACTION;
	"
	bmc_log "set_kernel_param $name"
	timestamp "exec_set_kernel_param:end $*"
}

proc_set_kernel_param()
{
	local opt="$1"
	local optarg="$2"
	case "$opt" in
	-h|--help)
		usage_set_kernel_param
		exit 0
		;;
	*)	INVALID_OPTION "$@"
		;;
	esac
	return 0
}

cmd_set_kernel_param()
{
	parse_options proc_set_kernel_param exec_set_kernel_param "$@"
}

######################################################################
usage_pull_bmc()
{
	echo "Usage: $myprog pull-bmc [OPTIONS] REPO NICKNAME"
	echo "    REPO is like this:"
	echo "        ssh://hg@bitbucket.org/alice/my_kernel"
	echo "        https://alice@bitbucket.org/alice/my_kernel"
	echo "        git@bitbucket.org:alice/my_kernel.git"
	echo "        https://alice@bitbucket.org/alice/my_kernel.git"
	echo "NOTE: 2 files (patterns are *kernel and *initrd) must exist."
	echo "      1 file (pattern is *param) may exist."
	echo "syntax of BMCfile:"
	echo "    kernel    FILE_NAME"
	echo "    initrd    FILE_NAME"
	echo "    param     FILE_NAME"
	echo "    kernelsig FILE_NAME"
	echo "    initrdsig FILE_NAME"
}

exec_pull_bmc()
{
	timestamp "exec_pull_bmc:begin $*"
	if [ $# -ne 2 ]; then
		usage_pull_bmc
		exit 1
	fi
	local repo="$1"; shift
	local name="$1"; shift
	[ $# -eq 0 ] || { ERROR "BUG: REST: $*"; exit 1; }

	local user_name; user_name="$($ID -un)"
	local repo_name; repo_name="$user_name-$(echo "$repo" | $SED 's|/|%|g;s|\.git$||')"

	local repo_top="$BMC_REPO_ROOT/$repo_name"
	if [ -d "$repo_top" ]; then
		case "$repo" in
		*.git)	(cd "$repo_top" && $GIT pull);;		# XXX
		*)	(cd "$repo_top" && $HG pull --update);;
		esac
	else
		SUDO mkdir -p "$repo_top"
		SUDO chown "$user_name" "$repo_top"
		case "$repo" in
		*.git)	$GIT clone "$repo" "$repo_top";;
		*)	$HG clone "$repo" "$repo_top";;
		esac
	fi

	local kernel_file=""
	local initrd_file=""
	local param_file=""
	local kernel_sig_file=""
	local initrd_sig_file=""
	local kernel_param=""
	local bmcfile="$repo_top/BMCfile"
	if [ -f "$bmcfile" ]; then
		local cmd args
		while read cmd args; do
			local abs_path="$repo_top/$args"
			INFO "BMCfile: $cmd $args"
			case "$cmd" in
			#*)		;;
			kernel)		kernel_file="$abs_path";;
			initrd)		initrd_file="$abs_path";;
			param)		param_file="$abs_path";;
			kernelsig)	kernel_sig_file="$abs_path";;
			initrdsig)	initrd_sig_file="$abs_path";;
			*)		ERROR "syntax error in BMCfile: $cmd $args"
					exit 1;;
			esac
			if [ ! -r "$abs_path" ]; then
				ERROR "cannot read $args"
				exit 1
			fi
		done < "$bmcfile"

		if [ -z "$kernel_file" ]; then 
			ERROR "kernel must be specified in BMCfile"
			exit 1
		fi
		if [ -z "$initrd_file" ]; then 
			ERROR "initrd must be specified in BMCfile"
			exit 1
		fi
		if [ -n "$param_file" ]; then
			kernel_param="$(cat "$param_file")"
		fi
	else
		kernel_file="$(echo "$repo_top/"*kernel)"
		initrd_file="$(echo "$repo_top/"*initrd)"
		param_file="$(echo "$repo_top/"*param)"
		kernel_sig_file="$(echo "$repo_top/"*kernel.sig)"
		initrd_sig_file="$(echo "$repo_top/"*initrd.sig)"

		if [ ! -r "$kernel_file" ]; then
			ERROR "No kernel file in repository"
			/bin/ls -l "$repo_top"
			exit 1
		fi
		if [ ! -r "$initrd_file" ]; then
			ERROR "No initrd file in repository"
			/bin/ls -l "$repo_top"
			exit 1
		fi
		if [ ! -r "$param_file" ]; then
			INFO "No param file in repository"
			/bin/ls -l "$repo_top"
		else
			kernel_param="$(cat "$param_file")"
		fi
		if [ ! -r "$kernel_sig_file" ]; then
			INFO "No kernel.sig file in repository"
			/bin/ls -l "$repo_top"
			kernel_sig_file=""
		fi
		if [ ! -r "$initrd_sig_file" ]; then
			INFO "No initrd.sig file in repository"
			/bin/ls -l "$repo_top"
			initrd_sig_file=""
		fi
	fi

	SQLwrite "
	BEGIN TRANSACTION;
	INSERT OR REPLACE
	INTO Kernel(kernel_name, kernel_file, kernel_sig_file, kernel_param)
	VALUES('$name', '${kernel_file#"$BMC_REPO_ROOT/"}', '${kernel_sig_file#"$BMC_REPO_ROOT/"}', '$kernel_param');
	INSERT OR REPLACE
	INTO Initrd(initrd_name, initrd_file, initrd_sig_file)
	VALUES('$name', '${initrd_file#"$BMC_REPO_ROOT/"}', '${initrd_sig_file#"$BMC_REPO_ROOT/"}');
	COMMIT TRANSACTION;
	"

	# XXX NOTE: INSERT OR REPLACE always update autoincrement'ed id.
	bmc_log "pull_bmc $name"
	timestamp "exec_pull_bmc:end $*"
}

proc_pull_bmc()
{
	local opt="$1"
	local optarg="$2"
	case "$opt" in
	-h|--help)
		usage_pull_bmc
		exit 0
		;;
	*)	INVALID_OPTION "$@"
		;;
	esac
	return 0
}

cmd_pull_bmc()
{
	parse_options proc_pull_bmc exec_pull_bmc "$@"
}

######################################################################
usage_pull()
{
	echo "Usage: $myprog pull [OPTIONS] NAME
  --nopull		skip docker pull"
}

check_archive_prefix()
{
	local targz="$1"
	local pathtar; pathtar="$($GNUTAR -t -z -f "$targz" | head -1)"
	case "$pathtar" in
	.|./*)	printf "./";;
	*)	printf "";;
	esac
}

bmc_check_docker_repo()
{
	local image="$1"; shift
	[ $# -eq 0 ] || { ERROR "BUG: REST: $*"; exit 1; }
	local name="${image%%:*}"
	local tag="${image#*:}"
	local result
	case "$image" in
	*:*)
		result=$($WGET --quiet --output-document=- "http://registry.hub.docker.com/v1/repositories/$name/tags" | $JQ --raw-output '.[]|.name' | grep "^$tag\$" || true)
		if [ "$result" != "$tag" ]; then
			ERROR "$image doesn't exist"
			exit 1
		fi
		;;
	*)
		result="$(SUDO $DOCKER search --no-trunc=true "$name" | $AWK -v NAME="$name" '$1==NAME {print $1;exit}')"
		if [ "$result" != "$name" ]; then
			ERROR "$image doesn't exist"
			exit 1
		fi
		;;
	esac
}

opt_pull_pull="true"
opt_pull_dummy="false"	# internal use only
opt_pull_note=""	# internal use only
exec_pull()
{
	"$opt_pull_dummy" || timestamp "exec_pull:begin $*"
	if [ $# -ne 1 ]; then
		usage_pull
		exit 1
	fi
	local name="$1"; shift
	[ $# -eq 0 ] || { ERROR "BUG: REST: $*"; exit 1; }

	if [ -n "$opt_pull_note" ]; then
		timestamp "exec_pull: $opt_pull_note"
	fi

	local rootfs_file; rootfs_file="$(echo "$name.tar.gz" | $SED 's|/|%|g')"
	local repo_rootfs="$BMC_REPO_ROOT/rootfs/$rootfs_file"
	local cidfile="$BMC_TMP/bmc_pull_cid_$$.tmp"

	if [ "$opt_pull_dummy" = "false" ]; then
		if [ "$opt_pull_pull" = "true" ]; then
			INFO "Pulling '$name' from dockerhub"
			SUDO $DOCKER pull "$name"
			INFO "Pulling '$name' from dockerhub: done"
		fi

		INFO "Extracting '$name'"
		SUDO $DOCKER run --cidfile="$cidfile" --name "BMC-pull-$$" "$name" /bin/true
		local cid; cid="$(cat "$cidfile")"
		SUDO rm -f "$cidfile"
		SUDO $DOCKER wait "$cid" >/dev/null
		mkdir -p "$(dirname "$repo_rootfs")"
		SUDO $DOCKER export "$cid" | gzip | SUDOwrite "$repo_rootfs"
		SUDO $DOCKER rm "$cid"
		INFO "Extracting '$name': done"

		## repack /etc
		INFO "Packing '$name'"
		local tmpdir; tmpdir="$(bmc_mktempdir)"
		bmc_rm_after "root@$tmpdir"
		local tarpfx; tarpfx="$(check_archive_prefix "$repo_rootfs")"
		SUDO $GNUTAR -x -z -f "$repo_rootfs" -C "$tmpdir" "$tarpfx"etc "$tarpfx"root
		### extract docker's ENV
		if [ ! -d "$tmpdir/etc/ssh" ]; then
			ERROR "/etc/ssh doesn't exist in $name"
			exit 1
		fi
		#(SUDO $DOCKER inspect --type image "$name" | $JQ '.[].Config.Env|.[]?') |
		(SUDO $DOCKER inspect --type image "$name" | $JQ '.[].Config.Env' | grep -v null | $JQ --raw-output '.[]') |
			SUDOappend "$tmpdir/etc/ssh/environment"
		SUDO $GNUTAR -c -z -f "$repo_rootfs-etc" -C "$tmpdir" .
		INFO "Packing '$name': done"
	fi

	# Note: even if dummy, insert the record for alloc_container().
	if [ "$(db_count Rootfs rootfs_name "$name")" -eq 0 ]; then
		SQLwrite "
		BEGIN TRANSACTION;
		INSERT INTO Rootfs(rootfs_name, rootfs_file) VALUES('$name', 'rootfs/$rootfs_file');
		COMMIT TRANSACTION;
		"
	fi
	bmc_log "pull $name"
	"$opt_pull_dummy" || timestamp "exec_pull:end $*"
}

proc_pull()
{
	local opt="$1"
	local optarg="$2"
	case "$opt" in
	-h|--help)
		usage_pull
		exit 0
		;;
	--nopull)
		opt_pull_pull="false"
		;;
	--note)
		opt_pull_note="${opt_pull_note:+$opt_pull_note }$optarg"
		return 2
		;;
	*)	INVALID_OPTION "$@"
		;;
	esac
	return 0
}

cmd_pull()
{
	parse_options proc_pull exec_pull "$@"
}

######################################################################
usage_images()
{
	echo "Usage: $myprog images [OPTIONS]
  --tsv		Show in Tab-Separated Values"
}

exec_images1()
{
 	local tbl="$1"; shift
	echo "$tbl"
	{
	echo ".mode tabs"
	echo ".header on"
	echo "SELECT $* FROM $tbl;"
	} | SQL | show_table "$opt_table_fmt"
}

exec_images()
{
	timestamp "exec_images:begin $*"
	if [ $# -ne 0 ]; then
		usage_images
		exit 1
	fi

	exec_images1 "Kernel" kernel_id ID, kernel_name name, kernel_file file, kernel_sig_file sig, kernel_param param
	echo ""
	exec_images1 "Initrd" initrd_id ID, initrd_name name, initrd_file file, initrd_sig_file sig
	echo ""
	exec_images1 "Rootfs" rootfs_id ID, rootfs_name name, rootfs_file file, rootfs_sig_file sig
	timestamp "exec_images:end $*"
}

proc_images()
{
	local opt="$1"
	local optarg="$2"
	case "$opt" in
	--tsv)
		opt_table_fmt="tsv"
		;;
	-h|--help)
		usage_images
		exit 0
		;;
	*)	INVALID_OPTION "$@"
		;;
	esac
	return 0
}

cmd_images()
{
	parse_options proc_images exec_images "$@"
}

######################################################################
usage_run()
{
	echo "Usage: $myprog run [OPTIONS] IMAGE KERNEL INITRD [COMMAND [ARG...]]
  -t, --tty=BOOL	Allocate a pseudo-TTY
  --cidfile=FILE	Write the container ID to the file
  --fstype=FSTYPE	choose type of providing rootfs: nfs, ramfs, s-ramfs, isofs (default: $BMC_DEFAULT_FSTYPE)
  --rank=RANK_EXPR	select a node which matches RANK_EXPR
                  	RANK_EXPR ::= any | eq N | ge N | le N
  --kernel-param=PARAM	kerel parameter
  --early=BOOL		xxx (default: auto)
  --pull-bg=BOOL	xxx (default: true)
  --timeout=SECOND	time to wait for up
  --reset-atime=BOOL	reset atime (for --fstype=nfs only)
"
}

rank_expr_to_sql()
{
	local expr="$1"; shift
	[ $# -eq 0 ] || { ERROR "BUG: REST: $*"; exit 1; }

	case "$expr" in
	any)	echo "1";;
	eq\ *)	echo "node_rank =  ${expr#"eq "}";;
	le\ *)	echo "node_rank <= ${expr#"le "}";;
	ge\ *)	echo "node_rank >= ${expr#"ge "}";;
	*)	ERROR "Invalid rank expression: $expr"; exit 1;;
	esac
}

alloc_container()
{
	local bmc_id="$1"; shift
	local base_name="$1"; shift
	local client_addr="$1"; shift
	local rank_expr="$1"; shift
	local kernel="$1"; shift
	local kernel_param="$1"; shift
	local initrd="$1"; shift
	local rootfs="$1"; shift
	local fstype="$1"; shift
	local command="$1"; shift
	[ $# -eq 0 ] || { ERROR "BUG: REST: $*"; exit 1; }

	local tpm_expr=""
	case "$fstype" in
	s-ramfs) tpm_expr="Node.have_tpm = 1";;
	esac

	SQLwrite "
	BEGIN TRANSACTION;
	INSERT INTO Container(bmc_id, base_name, client_addr, kernel_id, kernel_param, initrd_id, rootfs_id, fstype, node_id, command)
		SELECT '$bmc_id', '$base_name', '$client_addr', Kernel.kernel_id, '$kernel_param', Initrd.initrd_id, Rootfs.rootfs_id, '$fstype', Node.node_id, '$command'
		FROM Kernel, Initrd, Rootfs, Node
		WHERE Kernel.kernel_name = '$kernel' AND
		      Initrd.initrd_name = '$initrd' AND
		      Rootfs.rootfs_name = '$image' AND
		      ${tpm_expr:+$tpm_expr AND}
		      ${rank_expr:+$rank_expr AND}
		      Node.node_id NOT IN (SELECT node_id FROM Container WHERE node_id IS NOT NULL)
		LIMIT 1
		;
	SELECT node_id FROM Container WHERE bmc_id = '$bmc_id';
	COMMIT TRANSACTION;
	"
	#return: node_id
}

change_container_state()
{
	local bmc_id="$1"; shift
	local state="$1"; shift
	[ $# -eq 0 ] || { ERROR "BUG: REST: $*"; exit 1; }

	SQLwrite "
	BEGIN TRANSACTION;
	UPDATE Container SET state = '$state' WHERE bmc_id = '$bmc_id';
	COMMIT TRANSACTION;
	"
}

customize_rootfs_ssh()
{
	local bmc_id="$1"; shift
	local dist_rootfs="$1"; shift
	[ $# -eq 0 ] || { ERROR "BUG: REST: $*"; exit 1; }

	local homedir; homedir="$(homeof root "$dist_rootfs")"

	## accept login: user@bmc_server -> root@worker_node
	SUDO mkdir -p -m 700 "$homedir/.ssh"
	{
		cat "$HOME"/.ssh/*.pub

		# XXX
		if [ -S "${SSH_AUTH_SOCK-.}" ]; then
			$SSH_ADD -L
		fi
	} | SUDOappend "$homedir/.ssh/authorized_keys"
	echo "PermitRootLogin yes" | SUDOappend "$dist_rootfs/etc/ssh/sshd_config"

	## copy environment and set some BMC variables
	local dst_addr; dst_addr="$(db_get_container "$bmc_id" ip4_addr_os)"
	local src_addr; src_addr="$(get_src_addr "$dst_addr")"
	echo "PermitUserEnvironment yes" | SUDOappend "$dist_rootfs/etc/ssh/sshd_config"
	{
		SUDO cat "$dist_rootfs/etc/ssh/environment"
		echo "BMCID=$bmc_id"
		echo "BMC_SERVER=$src_addr"
		echo "BMC_CLIENT=$dst_addr"
	} | SUDOappend "$homedir/.ssh/environment"

	### accept login: bmc_server <- worker_node
	### ssh-keygen
	#local bits="1024"	#XXX
	#local type="rsa"	#XXX
	#local passphrase=""	#XXX
	#SUDO $SSH_KEYGEN -q -b "$bits" -t "$type" -N "$passphrase" -C "BMC" -f "$homedir/.ssh/id_$type"
}
customize_rootfs_rc_local()
{
	local bmc_id="$1"; shift
	local dist_rootfs="$1"; shift
	[ $# -eq 0 ] || { ERROR "BUG: REST: $*"; exit 1; }

	## hack: activate /etc/rc.local
	local rc_local
	rc_local="$(SUDO readlink -f "$dist_rootfs/etc/rc.local")"
	SUDO chmod +x "$rc_local"

	## kicker
	## XXX FIXME: curl or wget?
	local dst_addr; dst_addr="$(db_get_container "$bmc_id" ip4_addr_os)"
	local src_addr; src_addr="$(get_src_addr "$dst_addr")"
	SUDO cp "$dist_rootfs/etc/rc.local" "$dist_rootfs/etc/rc.local.bak"
	SUDO $SED "
/^exit 0/{s/^.*//}
\$a\\
curl 'http://$src_addr/$BMC_CGI_PATH/notify-bmc?bmcid=$bmc_id&status=ok' || true\\
wget -O/dev/null 'http://$src_addr/$BMC_CGI_PATH/notify-bmc?bmcid=$bmc_id&status=ok' || true
" "$dist_rootfs/etc/rc.local.bak" | SUDOwrite "$dist_rootfs/etc/rc.local"
}
customize_rootfs_resolv_conf()
{
	local bmc_id="$1"; shift
	local dist_rootfs="$1"; shift
	[ $# -eq 0 ] || { ERROR "BUG: REST: $*"; exit 1; }

	## hack: make /etc/resolv.conf for dns setting.
	local dns; dns="$(db_get_container "$bmc_id" dns_os)"
	#echo "nameserver $dns"  | SUDOappend "$dist_rootfs/etc/resolv.conf"		#XXX FIXME when the original nameserver is reachable
	echo "nameserver $dns"  | SUDOwrite "$dist_rootfs/etc/resolv.conf"		#XXX FIXME when the original nameserver is NOT reachable
}
customize_rootfs_hosts()
{
	local bmc_id="$1"; shift
	local dist_rootfs="$1"; shift
	[ $# -eq 0 ] || { ERROR "BUG: REST: $*"; exit 1; }

	local node_name; node_name="$(db_get_container "$bmc_id" node_name)"
	local addr; addr="$(db_get_container "$bmc_id" ip4_addr_os)"

	{
		echo "$addr $node_name"
		echo "127.0.0.1 localhost"
		echo "::1 localhost ip6-localhost ip6-loopback"
		echo "fe00::0 ip6-localnet"
		echo "ff00::0 ip6-mcastprefix"
		echo "ff02::1 ip6-allnodes"
		echo "ff02::2 ip6-allrouters"
	} | SUDOappend "$dist_rootfs/etc/hosts"

	echo "$node_name" | SUDOwrite "$dist_rootfs/etc/hostname"
}
customize_rootfs_timestamp()
{
	local bmc_id="$1"; shift
	local dist_rootfs="$1"; shift
	[ $# -eq 0 ] || { ERROR "BUG: REST: $*"; exit 1; }

	{
		echo '#!/bin/sh'
		echo 'TAG="$1"; shift'
		echo 'URL="http://$BMC_SERVER/cgi-bin/bmc-debug"'
		echo 'curl -s "${URL}?${TAG}:begin_bmcid=${BMCID}" -o /dev/null || wget -O/dev/null "${URL}?${TAG}:begin_bmcid=${BMCID}"'
		echo '"$@"'
		echo 'ST=$?'
		echo 'curl -s "${URL}?${TAG}:end_bmcid=${BMCID}" -o /dev/null || wget -O/dev/null "${URL}?${TAG}:end_bmcid=${BMCID}"'
		echo 'exit $ST'
	} | SUDOwrite "$dist_rootfs/etc/timestamp"
	SUDO chmod +x "$dist_rootfs/etc/timestamp"
}
customize_rootfs_localtime()
{
	local bmc_id="$1"; shift
	local dist_rootfs="$1"; shift
	[ $# -eq 0 ] || { ERROR "BUG: REST: $*"; exit 1; }

	SUDO rm -f "$dist_rootfs/etc/localtime"
	SUDO cp "/etc/localtime" "$dist_rootfs/etc/localtime"
}
customize_rootfs()
{
	local bmc_id="$1"; shift
	local dist_rootfs="$1"; shift
	[ $# -eq 0 ] || { ERROR "BUG: REST: $*"; exit 1; }

	customize_rootfs_ssh "$bmc_id" "$dist_rootfs"
	customize_rootfs_rc_local "$bmc_id" "$dist_rootfs"
	customize_rootfs_resolv_conf "$bmc_id" "$dist_rootfs"
	customize_rootfs_hosts "$bmc_id" "$dist_rootfs"
	customize_rootfs_timestamp "$bmc_id" "$dist_rootfs"
	customize_rootfs_localtime "$bmc_id" "$dist_rootfs"
}

chmod_for_httpd()
{
	local file="$1"
	SUDO chown "$HTTPD_USER:$HTTPD_GROUP" "$file"
	SUDO chmod a=r "$file"
}

get_dist_rootfs()
{
	local fstype="$1"; shift
	[ $# -eq 0 ] || { ERROR "BUG: REST: $*"; exit 1; }

	case "$fstype" in
	nfs)		echo "$BMC_DISTFS_ROOT/$base_name" ;;
	ramfs|s-ramfs)	echo "$BMC_DIST_ROOT/rootfs/$base_name" ;;
	isofs)		;;
	*)		{ ERROR "BUG: $fstype"; exit 1; }
	esac
}

prepare_files()
{
	local bmc_id="$1"; shift
	local base_name="$1"; shift
	local kernel="$1"; shift
	local initrd="$1"; shift
	local rootfs="$1"; shift
	local fstype="$1"; shift
	[ $# -eq 0 ] || { ERROR "BUG: REST: $*"; exit 1; }

	local kernel_file; kernel_file="$(db_get Kernel kernel_file kernel_name "$kernel")"
	local initrd_file; initrd_file="$(db_get Initrd initrd_file initrd_name "$initrd")"
	local rootfs_file; rootfs_file="$(db_get Rootfs rootfs_file rootfs_name "$rootfs")"
	local kernel_sig_file; kernel_sig_file="$(db_get Kernel kernel_sig_file kernel_name "$kernel")"
	local initrd_sig_file; initrd_sig_file="$(db_get Initrd initrd_sig_file initrd_name "$initrd")"

	local repo_kernel="$BMC_REPO_ROOT/$kernel_file"
	local repo_initrd="$BMC_REPO_ROOT/$initrd_file"
	local repo_rootfs="$BMC_REPO_ROOT/$rootfs_file"
	local repo_kernel_sig="$BMC_REPO_ROOT/$kernel_sig_file"
	local repo_initrd_sig="$BMC_REPO_ROOT/$initrd_sig_file"

	local dist_kernel="$BMC_DIST_ROOT/kernel/K$base_name"
	local dist_initrd="$BMC_DIST_ROOT/initrd/I$base_name"
	local dist_rootfs; dist_rootfs="$(get_dist_rootfs "$fstype")"
	local dist_kernel_sig="$BMC_DIST_ROOT/kernel/K$base_name.sig"
	local dist_initrd_sig="$BMC_DIST_ROOT/initrd/I$base_name.sig"

	[ -f "$repo_kernel" ] || { ERROR "BROKEN: $repo_kernel doesn't exist"; exit 1; }
	[ -f "$repo_initrd" ] || { ERROR "BROKEN: $repo_initrd doesn't exist"; exit 1; }
	[ -e "$repo_rootfs" ] || { ERROR "BROKEN: $repo_rootfs doesn't exist"; exit 1; }
	[ -e "$repo_rootfs-etc" ] || { ERROR "BROKEN: $repo_rootfs-etc doesn't exist"; exit 1; }
	[ -z "$kernel_sig_file" -o -f "$repo_kernel_sig" ] || { ERROR "BROKEN: $repo_kernel_sig doesn't exist"; exit 1; }
	[ -z "$initrd_sig_file" -o -f "$repo_initrd_sig" ] || { ERROR "BROKEN: $repo_initrd_sig doesn't exist"; exit 1; }

	# copy kernel
	bmc_rm_after "root@$dist_kernel"
	SUDO cp "$repo_kernel" "$dist_kernel"
	chmod_for_httpd "$dist_kernel"

	# copy initrd
	bmc_rm_after "root@$dist_initrd"
	SUDO cp "$repo_initrd" "$dist_initrd"
	chmod_for_httpd "$dist_initrd"

	# copy kernel sig
	if [ -n "$kernel_sig_file" ]; then
		bmc_rm_after "root@$dist_kernel_sig"
		SUDO cp "$repo_kernel_sig" "$dist_kernel_sig"
		chmod_for_httpd "$dist_kernel_sig"
	fi

	# copy initrd sig
	if [ -n "$initrd_sig_file" ]; then
		bmc_rm_after "root@$dist_initrd_sig"
		SUDO cp "$repo_initrd_sig" "$dist_initrd_sig"
		chmod_for_httpd "$dist_initrd_sig"
	fi

	# copy rootfs
	case "$fstype" in
	nfs)
		# copy rootfs, and customize
		if [ -e "$dist_rootfs" ]; then
			ERROR "INTERNAL ERROR: $dist_rootfs already exists"
			exit 1
		fi
		SUDO mkdir "$dist_rootfs"
		#SUDO chown XXX
		#SUDO chmod XXX
		SUDO $GNUTAR -x -z -f "$repo_rootfs" -C "$dist_rootfs"
		SUDO $GNUTAR -x -z -f "$repo_rootfs-etc" -C "$dist_rootfs"
		customize_rootfs "$bmc_id" "$dist_rootfs"
		;;
	ramfs|s-ramfs)
		# customize
		if [ -e "$dist_rootfs" ]; then
			ERROR "INTERNAL ERROR: $dist_rootfs already exists"
			exit 1
		fi
		if [ -e "$dist_rootfs.tar.gz" ]; then
			ERROR "INTERNAL ERROR: $dist_rootfs.tar.gz already exists"
			exit 1
		fi
		SUDO mkdir "$dist_rootfs"
		#SUDO chown XXX
		#SUDO chmod XXX
		bmc_rm_after "root@$dist_rootfs"
		SUDO $GNUTAR -x -z -f "$repo_rootfs-etc" -C "$dist_rootfs"
		customize_rootfs "$bmc_id" "$dist_rootfs"
		bmc_rm_after "root@$dist_rootfs-etc.tar.gz"
		SUDO $GNUTAR -c -z -f "$dist_rootfs-etc.tar.gz" -C "$dist_rootfs" etc root	# XXX FIXME *-etc.tar.gz, but /etc and /root...
		[ -f "$dist_rootfs-etc.tar.gz" ] || { ERROR "fail to make $dist_rootfs-etc.tar.gz"; exit 1; }
		chmod_for_httpd "$dist_rootfs-etc.tar.gz"
		SUDO rm -rf "$dist_rootfs"
		bmc_rm_after "root@$dist_rootfs.tar.gz"
		SUDO cp "$repo_rootfs" "$dist_rootfs.tar.gz"
		[ -f "$dist_rootfs.tar.gz" ] || { ERROR "fail to make $dist_rootfs.tar.gz"; exit 1; }
		chmod_for_httpd "$dist_rootfs.tar.gz"
		;;
	isofs)
		;;
	*)
		ERROR "Internal Error: fstype=$fstype"
		exit 1
		;;
	esac

	# hack: remove worker's host key from ~/.ssh/known_hosts
	local addr; addr="$(db_get_container "$bmc_id" ip4_addr_os)"
	# NOTE: ssh-keygen -R will fail if ~/.ssh/known_hosts does not exist.
	$SSH_KEYGEN -R "$addr" || true
}

homeof()
{
	local name="$1"; shift
	local dist_rootfs="$1"; shift
	[ $# -eq 0 ] || { ERROR "BUG: REST: $*"; exit 1; }

	local passwd_file="$dist_rootfs/etc/passwd"
	if [ -f "$passwd_file" ]; then
		$AWK -v ROOT="$dist_rootfs" -v NAME="$name" -F: '$1==NAME { print ROOT $6; exit }' "$passwd_file"
	else
		# XXX hack for ramfs
		case "$name" in
		root)	echo "$dist_rootfs/root";;
		*)	echo "$dist_rootfs/home/$name";;
		esac
	fi
}

amt_change_power_state()
{
	local pstate="$1"; shift
	local ip4_addr="$1"; shift
	local password="$1"; shift
	[ $# -eq 0 ] || { ERROR "BUG: REST: $*"; exit 1; }

	local powerstate
	case "$pstate" in
	on)	powerstate="2";;
	off)	powerstate="8";;
	reset)	powerstate="5";;
	*)	ERROR "BUG: invalkd pstate: $pstate"; exit 1;;
	esac
	# ref: http://schemas.dmtf.org/wbem/cim-html/2/CIM_PowerManagementService.html 

	local infile; infile="$(bmc_mktemp)"
	bmc_rm_after "$infile"
	local outfile; outfile="$(bmc_mktemp)"
	bmc_rm_after "$outfile"

	# ref: https://bugs.launchpad.net/maas/+bug/1331214
	{
	echo '<p:RequestPowerStateChange_INPUT xmlns:p="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_PowerManagementService">'
	echo "  <p:PowerState>$powerstate</p:PowerState>"
	echo '  <p:ManagedElement xmlns:wsa="http://schemas.xmlsoap.org/ws/2004/08/addressing"'
	echo '		    xmlns:wsman="http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd">'
	echo '    <wsa:Address>http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous</wsa:Address>'
	echo '    <wsa:ReferenceParameters>'
	echo '      <wsman:ResourceURI>http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ComputerSystem</wsman:ResourceURI>'
	echo '      <wsman:SelectorSet>'
	echo '        <wsman:Selector Name="CreationClassName">CIM_ComputerSystem</wsman:Selector>'
	echo '        <wsman:Selector Name="Name">ManagedSystem</wsman:Selector>'
	echo '      </wsman:SelectorSet>'
	echo '    </wsa:ReferenceParameters>'
	echo '  </p:ManagedElement>'
	echo '</p:RequestPowerStateChange_INPUT>'
	} >"$infile"

	#export WSMAN_USER=admin
	#export WSMAN_PASS="$password"
	local res="0"
	$WSMANCLI --hostname="$ip4_addr" --port=16992 \
		--method=RequestPowerStateChange --input="$infile" \
		--noverifypeer --noverifyhost \
		--username=admin --password="$password" \
		invoke \
		'http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_PowerManagementService?SystemCreationClassName=CIM_ComputerSystem,SystemName=Intel(r) AMT,CreationClassName=CIM_PowerManagementService,Name=Intel(r) AMT Power Management Service' \
		>"$outfile" 2>&1 || res="$?"
	unset WSMAN_USER
	unset WSMAN_PASS
	if [ "$res" -ne 0 ]; then
		ERROR "AMT RequestPowerStateChange $pstate failed"
		cat "$outfile" >&2
		return 1
	fi
}
poweron_node()
{
	local node_id="$1"; shift
	[ $# -eq 0 ] || { ERROR "BUG: REST: $*"; exit 1; }

	local method; method="$(db_get Node method_mgmt node_id "$node_id")"
	local mac_addr; mac_addr="$(db_get Node mac_addr_mgmt node_id "$node_id")"
	local ip4_addr; ip4_addr="$(db_get Node ip4_addr_mgmt node_id "$node_id")"
	local password; password="$(db_get Node password_mgmt node_id "$node_id")"
	local usr="root"
	local psw="$password"
	case "$password" in
	*@*) usr="${password%%@*}"; psw="${password#$usr@}" ;;
	esac
	case "$method" in
	wol)
		SUDO $ETHERWAKE -i "$ETHDEV" "$mac_addr"
		;;
	amt)
		amt_change_power_state on "$ip4_addr" "$password" || return 1
		;;
	amt-soap)
		export AMT_PASSWORD="$password"
		local tmpfile; tmpfile="$(bmc_mktemp)"
		bmc_rm_after "$tmpfile"
		SUDO -E $EXPECT -c "spawn $AMTTOOL $ip4_addr:16992 powerup; expect \"powerup\"; send \"yes\n\"; expect \"execute: powerup\n\"; wait; send_user \"OK-BMC\n\"; " </dev/null >"$tmpfile"
		unset AMT_PASSWORD
		local lastline; lastline="$(tail -1 "$tmpfile")"
		rm -f "$tmpfile"	# FIXME: workaround when opt_run_early=true.
		case "$lastline" in
		OK-BMC) ;;
		*)	ERROR "$AMTTOOL powerup failed"
			return 1
			;;
		esac
		;;
	ipmi)
		$IPMITOOL -I lanplus -H "$ip4_addr" -U "$usr" -P "$psw" chassis power up
		;;
	*)
		ERROR "poweron: $method is not supported"
		;;
	esac
	return 0
}
poweron_node_task()
{
	local tag="$1"; shift
	local node_id="$1"; shift
	[ $# -eq 0 ] || { ERROR "BUG: REST: $*"; exit 1; }

	timestamp "$tag poweron:begin"
	retry "$MAX_RETRY" "$RETRY_INTERVAL" poweron_node "$node_id"
	timestamp "exec_run poweron:end"
	change_container_state "$bmc_id" "up"
}

poweroff_node()
{
	local tag="$1"; shift
	local bmc_id="$1"; shift
	local node_id="$1"; shift
	local state="$1"; shift
	[ $# -eq 0 ] || { ERROR "BUG: REST: $*"; exit 1; }

	timestamp "$tag poweroff:begin bmcid=$bmc_id"
	local method; method="$(db_get Node method_mgmt node_id "$node_id")"
	local mac_addr; mac_addr="$(db_get Node mac_addr_mgmt node_id "$node_id")"
	local ip4_addr; ip4_addr="$(db_get Node ip4_addr_mgmt node_id "$node_id")"
	local password; password="$(db_get Node password_mgmt node_id "$node_id")"
	local usr="root"
	local psw="$password"
	case "$password" in
	*@*) usr="${password%%@*}"; psw="${password#$usr@}" ;;
	esac
	case "$method" in
	wol)
		case "$state" in
		running)
			ip4_addr="$(db_get Node ip4_addr_os node_id "$node_id")"
			INFO "ssh root@$ip4_addr $POWEROFF"
			$SSH -o "StrictHostKeyChecking=no" "root@$ip4_addr" "$POWEROFF" || true
			;;
		*)
			WARN "poweroff: $method is not supported on state $state"
			;;
		esac
		;;
	amt)
		amt_change_power_state off "$ip4_addr" "$password"
		;;
	amt-soap)
		export AMT_PASSWORD="$password"
		SUDO -E $EXPECT -c "spawn $AMTTOOL $ip4_addr:16992 powerdown ; expect \"powerdown\"; send \"yes\n\"; interact;"
		# XXX FIXME check amttool succeeded...
		unset AMT_PASSWORD
		sleep "$BMC_POWERDOWN_WAIT"	# XXX WORKAROUND amttool says 'invalid command'
		;;
	ipmi)
		$IPMITOOL -I lanplus -H "$ip4_addr" -U "$usr" -P "$psw" chassis power down
		sleep "$BMC_POWERDOWN_WAIT"	# XXX WORKAROUND
		;;
	*)
		ERROR "poweroff: $method is not supported"
		;;
	esac
	timestamp "$tag poweroff:end"
}

delwait()
{
	local xfile="$1"; shift
	local deadline="$1"; shift
	[ $# -eq 0 ] || { ERROR "BUG: REST: $*"; exit 1; }

	# XXX racecondition: if xfile is deleted..
	if [ ! -e "$xfile" ]; then
		return 0
	fi

	local timeout="$((deadline - $($DATE '+%s')))"
	if [ "$timeout" -le 0 ]; then
		ERROR "delwait:$xfile: timed out"
		exit 1
	fi
	if type "$INOTIFYWAIT" >/dev/null 2>&1; then
		local res="0"
		$INOTIFYWAIT --quiet --timeout="$timeout" --event=delete_self "$xfile" >/dev/null || res="$?"
		case "$res" in
		0) ;;
		1) ERROR "delwait:$xfile: failed"; exit 1;;
		2) ERROR "delwait:$xfile: timed out"; exit 1;;
		esac
	else
		local I
		step=0.1
		for I in $(seq 0 "$step" "$timeout" | $SED '1d'); do
			sleep "$step"
			if [ ! -e "$xfile" ]; then
				return 0
			fi
		done
		ERROR "delwait:$xfile: timed out"
		exit 1
	fi
}

opt_run_rank=""
opt_run_tty="false"
opt_run_fstype="${BMC_DEFAULT_FSTYPE:-NO}"
opt_run_kernel_param=""
opt_run_early="auto"
opt_run_pull_bg="true"
opt_run_timeout="$BMC_RUN_TIMEOUT"
opt_run_reset_atime="false"
exec_run()
{
	timestamp "exec_run:begin $*"
	if [ $# -lt 3 ]; then
		ERROR "Too few arguments"
		usage_run
		exit 1
	fi
	local image="$1"; shift
	local kernel="$1"; shift
	local initrd="$1"; shift
	local command="${*:-}"
	local now; now="$($DATE '+%s')"
	local deadline; deadline="$((now + opt_run_timeout))"

	local opt_ssh_tty
	case "$opt_run_tty" in
	true)	opt_ssh_tty="-tt";;
	false)	opt_ssh_tty="";;
	*)	ERROR "invalid --tty option value: $opt_run_tty"
		exit 1
		;;
	esac
	case "$opt_run_early" in
	auto|true|false)	;;
	*)	ERROR "invalid --early option value: $opt_run_early"
		exit 1
		;;
	esac

	local fstype="$opt_run_fstype"
	case "$fstype" in
	nfs|ramfs|s-ramfs|isofs) ;;
	NO)	ERROR "fsype must be specified"
		exit 1
		;;
	*)	ERROR "Invalid fsype: $fstype"
		exit 1
		;;
	esac

	if "$opt_run_reset_atime" && [ "$fstype" != "nfs" ]; then
		ERROR "--reset-atime=true requires --fstype=nfs"
		exit 1
	fi

	if [ "$(db_count Kernel kernel_name "$kernel")" -eq 0 ]; then
		ERROR "$kernel doesn't exist"
		exit 1
	fi
	if [ "$(db_count Initrd initrd_name "$initrd")" -eq 0 ]; then
		ERROR "$initrd doesn't exist"
		exit 1
	fi
	if [ "$fstype" = "s-ramfs" ]; then
		if [ -z "$(db_get Kernel kernel_sig_file kernel_name "$kernel")" ]; then
			ERROR "$kernel isn't signed"
			exit 1
		fi
		if [ -z "$(db_get Initrd initrd_sig_file initrd_name "$initrd")" ]; then
			ERROR "$kernel isn't signed"
			exit 1
		fi
	fi
	local pullbg="false"
	if [ "$(db_count Rootfs rootfs_name "$image")" -eq 0 ]; then
		INFO "Unable to find image '$image' on the local"
		if [ "$opt_run_pull_bg" = "true" ]; then
			pullbg="true"
			opt_pull_dummy="true"
			bmc_push_undo "exec_rm_image '$image'"
			exec_pull "$image"
		else
			timestamp "exec_run pull:begin image=$image"
			opt_pull_pull="false"
			exec_pull "$image"
			timestamp "exec_run pull:end"
		fi
	fi

	local client_addr; client_addr="$(hostname)"	# FIXME
	local bmc_id; bmc_id="$(new_id)"
	local base_name; base_name="$(new_id)"

	timestamp "exec_run alloc:begin"
	local node_id; node_id="$(alloc_container "$bmc_id" "$base_name" "$client_addr" "$opt_run_rank" "$kernel" "$opt_run_kernel_param" "$initrd" "$image" "$fstype" "$command")"
	if [ -z "$node_id" ]; then
		ERROR "Node exhausted"
		exit 1
	fi
	timestamp "exec_run alloc:end bmcid=$bmc_id node=$node_id"
	local node_name; node_name="$(db_get Node node_name node_id "$node_id")"
	bmc_log "run $bmc_id on $node_name"
	INFO "BMC_ID: $bmc_id on $node_name"

	bmc_push_undo "exec_rm1 '$bmc_id'"

	local pid_pull
	if [ "$pullbg" = "true" ]; then
		INFO "Checking whether image '$image' exists on DockerRepository"
		timestamp "exec_run check_image:begin image=$image"
		bmc_check_docker_repo "$image"
		timestamp "exec_run check_image:end image=$image"
		
		INFO "Pulling image '$image' on background"
		timestamp "exec_run pull_bg:begin image=$image"
		$BMC_BIN_DIR/bmc pull --nopull --note="bmcid=$bmc_id" --note="parent=$$" "$image" &
		pid_pull="$!"
		bmc_push_undo "(kill -0 $pid_pull 2>/dev/null && kill $pid_pull && wait $pid_pull) || true"
	fi

	if [ "$opt_run_early" = "auto" ] ;then
		local method; method="$(db_get Node method_mgmt node_id "$node_id")"
		case "$method" in
		wol)	opt_run_early="false";;
		*)	opt_run_early="true";;
		esac
		INFO "using --early=$opt_run_early (because method=$method)"
	fi

	local pid_poweron
	if [ "$opt_run_early" = "true" ]; then
		poweron_node_task "exec_run" "$node_id" &
		pid_poweron=$!
		bmc_push_undo "(kill -0 $pid_poweron 2>/dev/null && kill $pid_poweron && wait $pid_poweron) || true; exec_kill1 '$bmc_id'"
	fi

	if [ "${opt_run_cidfile+YES}" = YES ]; then
		echo "$bmc_id" >"$opt_run_cidfile" || true
	fi

	if [ "$pullbg" = "true" ]; then
		INFO "Wait for pulling image '$image'"
		wait "$pid_pull"
		timestamp "exec_run pull_bg:end"
	fi

	timestamp "exec_run prepare:begin"
	prepare_files "$bmc_id" "$base_name" "$kernel" "$initrd" "$image" "$fstype"
	timestamp "exec_run prepare:end"

	if "$opt_run_reset_atime"; then
		timestamp "exec_run reset_atime:begin"
		SUDO find "$(get_dist_rootfs "$fstype")" -type f -print0 | SUDO xargs -0 touch -a -t 197001010000
		timestamp "exec_run reset_atime:end"
	fi

	local xfile; xfile="$BMC_INCOMING/up-$bmc_id"
	rm -f "$xfile" || true
	touch "$xfile"
	SUDO chown "$HTTPD_USER:$HTTPD_GROUP" "$xfile"

	if [ "$opt_run_early" = "true" ]; then
		wait "$pid_poweron"
	else
		poweron_node_task "exec_run" "$node_id"
		bmc_push_undo "exec_kill1 '$bmc_id'"
	fi

	change_container_state "$bmc_id" "pending"

	local node_addr; node_addr="$(db_get Node ip4_addr_os node_id "$node_id")"

	INFO "Waiting for $node_addr"
	timestamp "exec_run waitnotify:begin"
	delwait "$xfile" "$deadline"	# $xfile will be deleted by cgi-notify-bmc.sh
	INFO "$node_addr is up"
	timestamp "exec_run waitnotify:end"
	local sfile; sfile="$BMC_INCOMING/status-$bmc_id"
	local boot_status; boot_status="$(cat "$sfile")"
	SUDO rm "$sfile" || true
	case "$boot_status" in
	ok)	;;
	*)	ERROR "boot failure: $boot_status"
		exit 1
		;;
	esac

	change_container_state "$bmc_id" "running"

	timestamp "exec_run checkport:begin"
	local ssh_port=22
	while ! $NC -v "$node_addr" "$ssh_port" </dev/null; do
		sleep 0.1
	done
	timestamp "exec_run checkport:end"
	timestamp "exec_run ssh:begin"
	$SSH $opt_ssh_tty -o "StrictHostKeyChecking=no" "root@$node_addr" "$command"
	timestamp "exec_run ssh:end"
	timestamp "exec_run:end $*"

	if "$opt_run_reset_atime"; then
		timestamp "exec_run list_new_atime:begin"
		local atime_out="$bmc_id-atime.out"
		INFO "generating $atime_out"
		(cd "$(get_dist_rootfs "$fstype")" && SUDO find . -type f -atime -1 -print) >"$atime_out"
		timestamp "exec_run list_new_atime:end"
	fi
}

proc_run()
{
	local opt="$1"
	local optarg="$2"
	case "$opt" in
	-i|--interactive)
		WARN "$opt is not implemented"
		;;
	-t)	opt_run_tty="true"
		;;
	--tty)	opt_run_tty="$optarg"
		return 2
		;;
	--cidfile)
		opt_run_cidfile="$optarg"
		return 2
		;;
	--fstype)
		opt_run_fstype="$optarg"
		return 2
		;;
	--rank)
		opt_run_rank="${opt_run_rank:+"${opt_run_rank} AND "}$(rank_expr_to_sql "$optarg")"
		return 2
		;;
	--kernel[-_]param)
		opt_run_kernel_param="$optarg"
		return 2
		;;
	--early)
		opt_run_early="$optarg"
		return 2
		;;
	--pull[-_]bg)
		opt_run_pull_bg="$optarg"
		return 2
		;;
	--timeout)
		opt_run_timeout="$optarg"
		return 2
		;;
	--reset[-_]atime)
		opt_run_reset_atime="$optarg"
		return 2
		;;
	-h|--help)
		usage_run
		exit 0
		;;
	*)	INVALID_OPTION "$@"
		;;
	esac
	return 0
}

cmd_run()
{
	parse_options proc_run exec_run "$@"
}

######################################################################
usage_attach()
{
	echo "Usage: $myprog attach [OPTIONS] CONTAINER [COMMAND [ARG...]]
  -t, --tty=BOOL	Allocate a pseudo-TTY"
}

opt_attach_tty="false"

exec_attach()
{
	timestamp "exec_attach:begin $*"
	if [ $# -lt 1 ]; then
		usage_attach
		exit 1
	fi
	local bmc_id="$1"; shift
	local command="${*:-}"

	local opt_ssh_tty
	case "$opt_attach_tty" in
	true)	opt_ssh_tty="-tt";;
	false)	opt_ssh_tty="";;
	*)	ERROR "invalid --tty option value: $opt_run_tty"
		exit 1
		;;
	esac

	local state; state="$(db_get Container state bmc_id "$bmc_id")"
	case "$state" in
	"")	ERROR "no such id: $bmc_id"
		exit 1
		;;
	running)
		local node_addr; node_addr="$(db_get_container "$bmc_id" ip4_addr_os)"
		$SSH $opt_ssh_tty -o "StrictHostKeyChecking=no" "root@$node_addr" "$command"
		;;
	*)
		ERROR "You cannot attach to a stopped container"
		exit 1
		;;
	esac
	timestamp "exec_attach:end $*"
}

proc_attach()
{
	local opt="$1"
	local optarg="$2"
	case "$opt" in
	-t)	opt_attach_tty="true"
		;;
	--tty)	opt_attach_tty="$optarg"
		return 2
		;;
	-h|--help)
		usage_attach
		exit 0
		;;
	*)	INVALID_OPTION "$@"
		;;
	esac
	return 0
}

cmd_attach()
{
	parse_options proc_attach exec_attach "$@"
}

######################################################################
usage_ps()
{
	echo "Usage: $myprog ps [OPTIONS]
  -a, --all=BOOL	Show all BMC
  -q, --quiet=BOOL	Only display numeric IDs
  --tsv			Show in Tab-Separated Values"
}

opt_ps_all="false"
opt_ps_quiet="false"
exec_ps()
{
	timestamp "exec_ps:begin $*"
	if [ $# -ne 0 ]; then
		usage_ps
		exit 1
	fi
	case "$opt_ps_quiet" in
	true|false)	;;
	*)	ERROR "invalid --quiet option value: $opt_ps_quiet"
		exit 1
		;;
	esac

	case "$opt_ps_quiet" in
	true)
		{
		echo ".header off"
		echo "SELECT bmc_id FROM Container"
		if [ "$opt_ps_all" = "false" ]; then
			echo "WHERE state != 'terminated'"
		fi
		echo "ORDER BY Container.created;"
		} | SQL
		;;
	false)
		{
		echo ".mode tabs"
		echo ".header on"
		echo "SELECT bmc_id, ip4_addr_os addr, client_addr, kernel_name, (Kernel.kernel_param || ' ' || Container.kernel_param) kernel_param, initrd_name, rootfs_name, node_name, fstype, command, created, state
		      FROM Container
		      LEFT OUTER JOIN Kernel ON Container.kernel_id = Kernel.kernel_id
		      LEFT OUTER JOIN Initrd ON Container.initrd_id = Initrd.initrd_id
		      LEFT OUTER JOIN Rootfs ON Container.rootfs_id = Rootfs.rootfs_id
		      LEFT OUTER JOIN Node ON Container.node_id = Node.node_id"
		if [ "$opt_ps_all" = "false" ]; then
			echo "WHERE state != 'terminated'"
		fi
		echo "ORDER BY Container.created;"
		} | SQL | show_table "$opt_table_fmt"
		;;
	esac
	timestamp "exec_ps:end $*"
}

proc_ps()
{
	local opt="$1"
	local optarg="$2"
	case "$opt" in
	-a)
		opt_ps_all="true"
		;;
	--all)
		opt_ps_all="$optarg"
		return 2
		;;
	-q)
		opt_ps_quiet="true";
		;;
	--quiet)
		opt_ps_quiet="$optarg";
		return 2
		;;
	--tsv)
		opt_table_fmt="tsv"
		;;
	-h|--help)
		usage_ps
		exit 0
		;;
	*)	INVALID_OPTION "$@"
		;;
	esac
	return 0
}

cmd_ps()
{
	parse_options proc_ps exec_ps "$@"
}

######################################################################
usage_kill()
{
	echo "Usage: $myprog kill [OPTIONS] CONTAINER [CONTAINER...]"
}

exec_kill1()
{
	timestamp "exec_kill1:begin $*"
	bmc_id="$1"; shift
	[ $# -eq 0 ] || { ERROR "BUG: REST: $*"; exit 1; }

	echo "$bmc_id"

	local state; state="$(db_get Container state bmc_id "$bmc_id")"
	case "$state" in
	terminated)
		;;
	up|pending|running)
		local node_id; node_id="$(db_get Container node_id bmc_id "$bmc_id")"
		if [ -z "$node_id" ]; then
			ERROR "INTERNALERROR: no such id: $bmc_id"
			return 0
		fi
		change_container_state "$bmc_id" "shutting-down"
		poweroff_node "kill" "$bmc_id" "$node_id" "$state"
		;;
	shutting-down)
		;;
	esac

	SQLwrite "
	BEGIN TRANSACTION;
	UPDATE Container SET state = 'terminated', node_id = NULL WHERE bmc_id = '$bmc_id';
	COMMIT TRANSACTION;
	"
	# XXX change_container_state "$bmc_id" "terminated"
	bmc_log "kill $bmc_id"
	timestamp "exec_kill1:end $*"
}

exec_kill()
{
	timestamp "exec_kill:begin $*"
	if [ $# -eq 0 ]; then
		ERROR "requires a minimum of 1 argument."
		usage_kill
		exit 1
	fi
	for bmc_id; do
		exec_kill1 "$bmc_id"
	done
	timestamp "exec_kill:end $*"
}

proc_kill()
{
	local opt="$1"
	local optarg="$2"
	case "$opt" in
	-h|--help)
		usage_kill
		exit 0
		;;
	*)	INVALID_OPTION "$@"
		;;
	esac
	return 0
}

cmd_kill()
{
	parse_options proc_kill exec_kill "$@"
}

######################################################################
usage_rm()
{
	echo "Usage: $myprog rm [OPTIONS] CONTAINER [CONTAINER...]
  -f|--force=BOOL	Force"
}

opt_rm_force="false"
exec_rm1()
{
	timestamp "exec_rm1:begin $*"
	bmc_id="$1"; shift
	[ $# -eq 0 ] || { ERROR "BUG: REST: $*"; exit 1; }

	if [ "$(db_count Container bmc_id "$bmc_id")" -eq 0 ]; then
		ERROR "no such id: $bmc_id"
		if [ "$opt_rm_force" = "false" ]; then
			return 1
		fi
	fi

	local state; state="$(db_get Container state bmc_id "$bmc_id")"

	if [ "$state" != "terminated" ]; then
		if [ "$opt_rm_force" = "false" ]; then
			ERROR "$bmc_id is running"
			exit 1
		fi
		INFO "$bmc_id is running"
		exec_kill1 "$bmc_id"
	fi

	local base_name; base_name="$(db_get Container base_name bmc_id "$bmc_id")"
	local dist_kernel="$BMC_DIST_ROOT/kernel/$base_name"
	local dist_initrd="$BMC_DIST_ROOT/initrd/$base_name"
	local dist_kernel_sig="$BMC_DIST_ROOT/kernel/$base_name.sig"
	local dist_initrd_sig="$BMC_DIST_ROOT/initrd/$base_name.sig"
	SUDO rm -f "$dist_kernel" "$dist_initrd" "$dist_kernel_sig" "$dist_initrd_sig"

	local dist_rootfs; dist_rootfs="$(get_dist_rootfs nfs)"	#XXX:FIXME dirty
	SUDO rm -rf "$dist_rootfs"
	local dist_root; dist_root="$(get_dist_rootfs ramfs)"	#XXX:FIXME dirty
	local FILE
	for FILE in "$dist_root"*; do
		SUDO rm -rf "$FILE"
	done

	SQLwrite "
	BEGIN TRANSACTION;
	DELETE FROM Container WHERE bmc_id = '$bmc_id';
	COMMIT TRANSACTION;
	"
	bmc_log "rm $bmc_id"
	timestamp "exec_rm1:end $*"
}

exec_rm()
{
	timestamp "exec_rm:begin $*"
	if [ $# -eq 0 ]; then
		ERROR "requires a minimum of 1 argument."
		usage_rm
		exit 1
	fi
	local res=0
	for bmc_id; do
		exec_rm1 "$bmc_id" || res=1
	done
	timestamp "exec_rm:end $*"
	return $res
}

proc_rm()
{
	local opt="$1"
	local optarg="$2"
	case "$opt" in
	-h|--help)
		usage_rm
		exit 0
		;;
	-f)
		opt_rm_force="true"
		;;
	--force)
		opt_rm_force="$optarg"
		return 2
		;;
	*)	INVALID_OPTION "$@"
		;;
	esac
	return 0
}

cmd_rm()
{
	parse_options proc_rm exec_rm "$@"
}

######################################################################

usage_timestamp()
{
	echo "Usage: $myprog timestamp ..."
}

cmd_timestamp()
{
	timestamp "$*"
	return 0
}

######################################################################

usage_version()
{
	echo "Usage: $myprog version"
}

cmd_version()
{
	INFO "version: @BMC_VERSION@"
	INFO "conf: $BMC_CONF"
}

######################################################################
usage()
{
	if [ $# -eq 0 ]; then
		usage_bmc
	else
		local arg; arg="$(echo "$1" | $SED 's/-/_/g')"
		if type "usage_$arg" >/dev/null 2>&1; then
			eval "usage_$arg"
		else
			ERROR "$arg is not a bmc command."
			exit 1
		fi
	fi
	return 0
}

usage_bmc()
{
	echo "\
Usage: $myprog [OPTIONS] COMMAND [arg...]\

Bare Metal Container

Options:
  -h,--help		Print usage

Commands:
  import-kernel copy-in kernel image.
  import-initrd copy-in initrd image.
  import-rootfs copy-in rootfs image.
  image-info	Show information
  rm-kernel	rm kernel image.
  rm-initrd	rm initrd image.
  rm-rootfs	rm rootfs image.
  rm-image	Remove a image.
  set-kernel-param	set kernel paramters
  pull-bmc	Pull a set of kernel image (a kernel and an initrd) from a hg or git server
  pull		Pull an image or a repository from a Docker registry server
  images	List images
  run		Run a command in a new container
  attach	Attach to a running container
  ps		List containers
  kill		Kill a running container
  rm		Remove one or more containers
  addnode	Add a worker node.
  delnode	Del a worker node.
  nodes		List worker nodes.
  version	Show the BMC version information

Run '$myprog COMMAND --help' for more information on a command.
"
}

proc_option()
{
	local opt="$1"
	local optarg="$2"
	case "$opt" in
	-h|--help)
		usage
		exit 0
		;;
	--debug)
		BMC_DEBUG=true
		;;
	-x)
		set -x	## XXX
		;;
	*)	INVALID_OPTION "$@"
		;;
	esac
	return 0
}

parse_command()
{
	if [ $# -eq 0 ]; then
		usage
		exit 1
	fi
	local cmd="$1"; shift
	case "$cmd" in
	help)	usage "$@"
		exit 0
		;;
	import-kernel)		cmd_import_kernel "$@";;
	import-initrd)		cmd_import_initrd "$@";;
	import-rootfs)		cmd_import_rootfs "$@";;
	image-info)		cmd_image_info "$@";;
	rm-kernel)		cmd_rm_kernel "$@";;
	rm-initrd)		cmd_rm_initrd "$@";;
	rm-rootfs)		cmd_rm_rootfs "$@";;
	rm-image)		cmd_rm_image "$@";;
	set-kernel-param)	cmd_set_kernel_param "$@";;
	pull-bmc)		cmd_pull_bmc "$@";;
	pull)			cmd_pull "$@";;
	images)			cmd_images "$@";;
	run)			cmd_run "$@";;
	attach)			cmd_attach "$@";;
	ps)			cmd_ps "$@";;
	kill)			cmd_kill "$@";;
	rm)			cmd_rm "$@";;
	addnode)		cmd_addnode "$@";;
	delnode)		cmd_delnode "$@";;
	nodes)			cmd_nodes "$@";;
	logs)			cmd_logs "$@";;
	timestamp)		cmd_timestamp "$@";;
	version)		cmd_version "$@";;
	*)	ERROR "Invalid command: $cmd"
		exit 1;;
	esac
	INFO "end: BMC $cmd succeeded"
	bmc_success
}

######################################################################
parse_options proc_option parse_command "$@"
exit 0
