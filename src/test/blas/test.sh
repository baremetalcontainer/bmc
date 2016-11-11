#!/bin/sh
set -uex

export LANG=C

BMC_CONF=/opt/bmc/etc/bmc.conf
. "$BMC_CONF"
. ../comm/meter.sh

#################### paramters

###
### programs (can be changed)
###
bmc="$BMC_BIN_DIR/bmc"
bmccopy="$BMC_TOOL_DIR/bmc-copy"
getimage="$BMC_TOOL_DIR/bmc-get-image"
sarnet=$BMC_TOOL_DIR/sarnet
watt=$BMC_TOOL_DIR/wattchecker
mkchart=$BMC_TOOL_DIR/mkchart
joule=$BMC_TOOL_DIR/joule

###
### settings (should be changed)
###
kernel="vmlinuz-3.13.11-ckt30"
initrd="initrd.img-3.13.11-ckt30"
rootfs="openblas.centos7.bmc"
fstype="ramfs"

###
### worker (should be changed)
###
rank_list="1"

###
### BLAS
###
#blas="atlas"	# use ATLAS
blas="openblas"	# use OpenBLAS

repeat=5

###
### monitoring
###
net_settling_time=1
pwr_settling_time=10
poweroff_guard_time=10	# time after amt poweroff before circuit off.
min_power_threshold=1
power_delay=4
bmc_run_guard_time=1

dev_watt=/dev/ttyUSB0
#dev_watt=""		# if dev_watt is empty, wattchecker is not invoked.

. ../comm/parse_arg.sh
#################### end

meter_init

cleanup()
{
	meter_stop
	exit 1
}
trap cleanup INT TERM EXIT

#### main

meter_start

# pull rootfs if it is not imported/pulled, 
$bmc image-info --rootfs "$rootfs" || $bmc pull --nopull $rootfs

# download openblas develop version.
OPENBLAS_ZIP=develop.zip
[ -f $OPENBLAS_ZIP ] || {
	make -f GNUmakefile.openblas download-openblas
}

build1()
{
	local rank="$1"; shift

	local blasimg; blasimg="$rootfs.blas.$rank"
	if $bmc image-info --rootfs "$blasimg"; then
		echo "INFO: SKIP building $blasimg (because already exists)"
		return
	fi

	# create a container
	"$bmc" run --cidfile=cid.out --rank="eq $rank" --fstype="$fstype" "$rootfs" "$kernel" "$initrd" true
	local bmcid; bmcid="$(cat cid.out)"; rm "cid.out"

	# build custom blas and run
	"$bmccopy" "GNUmakefile.$blas" "$bmcid:/root/GNUmakefile"
	"$bmccopy" "setsmt.sh" "$bmcid:/root/setsmt.sh"
	"$bmccopy" "check.m" "$bmcid:/root/check.m"
	"$bmccopy" "bench.m" "$bmcid:/root/bench.m"
	"$bmccopy" "$OPENBLAS_ZIP" "$bmcid:/root/$OPENBLAS_ZIP"

	local smt
	#for smt in on off; do	# xxx
	for smt in on; do
		# build
		"$bmc" attach "$bmcid" "cd /root && sh setsmt.sh $smt && make all OPT=/root/opt-$smt && make clean"
	done
	"$bmc" attach "$bmcid" "cd /root && ln -s opt-on opt-off"	# xxx

	# suck up
	"$getimage" "$bmcid" "$blasimg".tar.gz
	"$bmc" import-rootfs "$blasimg" "$blasimg.tar.gz"

	"$bmc" kill "$bmcid"
	"$bmc" rm "$bmcid"
	sleep $poweroff_guard_time
}
build()
{
	for rank in $rank_list; do
		build1 "$rank" 2>&1 | tee "build-R$rank.log"
	done
}

mean()
{
	awk '{sum += $1}; END{print sum/NR}'
}
bench_smt1()
{
	local rank="$1"; shift

	local blasimg; blasimg="$rootfs.blas.$rank"
	"$bmc" run --cidfile=cid.out --rank="eq $rank" --fstype="$fstype" "$blasimg" "$kernel" "$initrd" true 
	local bmcid; bmcid="$(cat cid.out)"; rm "cid.out"
	echo "$bmcid" >>./bmcid_list.out

	local size i target smt
	for size in 1600 3200 6400 12800 25600; do
		for i in $(seq 1 $repeat); do
			for target in pkglapack pkgblas myblas; do
				for smt in on off; do
					local label="blas-$size-$target-Smt$smt-$i"
					"$bmc" timestamp "$label:begin bmcid=$bmcid"
					"$bmc" attach "$bmcid" "cd /root && sh setsmt.sh $smt && make bench-$target OPT=/root/opt-$smt SIZE=$size" 2>&1 | tee -a res-$label.out
					"$bmc" timestamp "$label:end bmcid=$bmcid"
					meter_request_report "$bmcid" "time" "xxx" "[$label" "$label]"
					meter_request_report "$bmcid" "pwr" "xxx" "[$label" "$label]"
				done
			done
		done
	done

	for target in pkglapack pkgblas myblas; do
		for smt in on off; do
			printf "GFLOPS($target $smt;mean): %s\n" "$(sed -n '/GFLOPS/{s/GFLOPS *= *//;p;}' res-*-$target-Smt$smt-*.out | mean)"
		done
	done

	"$bmc" kill "$bmcid"
	"$bmc" rm "$bmcid"
	sleep $poweroff_guard_time
}
bench_smt()
{
	for rank in $rank_list; do
		bench_smt1 "$rank" 2>&1 | tee "bench-R$rank.log"
	done
}

bench_cross1()
{
	local img_rank="$1"; shift
	local node_rank="$1"; shift
	local smt=on

	local blasimg="$rootfs.blas.$img_rank"
	"$bmc" run --cidfile=cid.out --rank="eq $node_rank" --fstype="$fstype" "$blasimg" "$kernel" "$initrd" "cd /root && make bench OPT=/root/opt-$smt"
	bmcid="$(cat cid.out)"; rm "cid.out"
	echo "$bmcid" >>./bmcid_list.out

	local i
	for i in $(seq 1 $repeat); do
		local label="blas-Smt$smt-Img$img_rank-Node$node_rank-$i"
		"$bmc" timestamp "$label:begin bmcid=$bmcid"
		"$bmc" attach "$bmcid" "cd /root && make bench OPT=/root/opt-$smt"
		"$bmc" timestamp "$label:end bmcid=$bmcid"
		meter_request_report "$bmcid" "time" "xxx" "[$label" "$label]"
		meter_request_report "$bmcid" "pwr" "xxx" "[$label" "$label]"
	done

	"$bmc" kill "$bmcid"
	"$bmc" rm "$bmcid"
	sleep $poweroff_guard_time
}
bench_cross()
{
	for img_rank in $rank_list; do
		for node_rank in $rank_list; do
			if [ "$img_rank" = "$node_rank" ]; then continue; fi
			bench_cross1 "$img_rank" "$node_rank" 2>&1 | tee "bench-I$img_rank-N$node_rank.log"
		done
	done
}

build
bench_smt
#bench_cross

meter_stop
trap - EXIT
meter_make_report >./report.out

echo "FIN"
exit 0
