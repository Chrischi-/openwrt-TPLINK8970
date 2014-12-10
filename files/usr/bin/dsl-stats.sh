#!/bin/sh
# original: /lib/functions/lantiq_dsl.sh
# Copyright (C) 2012-2014 OpenWrt.org
# modified by ambrosa rev 0.01  09-dec-2014
# collect and record into a file some DSL statistics
# run with cron i.e. every 15 minutes
#
# setup OUTPUT_FILE below

OUTPUT_FILE="/tmp/dsl_stats.csv"


# -----------------------------------------


if [ "$( which vdsl_cpe_control )" ]; then
	XDSL_CTRL=vdsl_cpe_control
else
	XDSL_CTRL=dsl_cpe_control
fi

#
# Basic functions to send CLI commands to the vdsl_cpe_control daemon
#
dsl_cmd() {
	killall -0 ${XDSL_CTRL} && (
		echo "$@" > /tmp/pipe/dsl_cpe0_cmd
		cat /tmp/pipe/dsl_cpe0_ack
	)
}
dsl_val() {
	echo $(expr "$1" : '.*'$2'=\([-\.[:alnum:]]*\).*')
}

#
# Simple divide by 10 routine to cope with one decimal place
#
dbt() {
	local a=$(expr $1 / 10)
	local b=$(expr $1 % 10)
	echo "${a}.${b}"
}
#
# Take a number and convert to k or meg
#
scale() {
	local val=$1
	local a
	local b

	if [ "$val" -gt 1000000 ]; then
		a=$(expr $val / 1000)
		b=$(expr $a % 1000)
		a=$(expr $a / 1000)
		printf "%d.%03d Mb" ${a} ${b}
	elif [ "$val" -gt 1000 ]; then
		a=$(expr $val / 1000)
		printf "%d Kb" ${a}
	else
		echo "${val} b"
	fi
}

#
# Read the data rates for both directions
#
data_rates() {
	local csg
	local dru
	local drd

	csg=$(dsl_cmd g997csg 0 1)
	drd=$(dsl_val "$csg" ActualDataRate)

	csg=$(dsl_cmd g997csg 0 0)
	dru=$(dsl_val "$csg" ActualDataRate)

	[ -z "$drd" ] && drd=0
	[ -z "$dru" ] && dru=0

	echo -n "${drd},${dru}," >> $OUTPUT_FILE
}


#
# Work out how long the line has been up
#
line_uptime() {
	local ccsg
	local et

	ccsg=$(dsl_cmd pmccsg 0 0 0)
	et=$(dsl_val "$ccsg" nElapsedTime)

	[ -z "$et" ] && et=0

	echo -n "${et}," >> $OUTPUT_FILE
}

#
# Get noise and attenuation figures
#
line_data() {
	local lsg
	local latnu
	local latnd
	local snru
	local snrd

	lsg=$(dsl_cmd g997lsg 1 1)
	latnd=$(dsl_val "$lsg" LATN)
	snrd=$(dsl_val "$lsg" SNR)

	lsg=$(dsl_cmd g997lsg 0 1)
	latnu=$(dsl_val "$lsg" LATN)
	snru=$(dsl_val "$lsg" SNR)

	[ -z "$latnd" ] && latnd=0
	[ -z "$latnu" ] && latnu=0
	[ -z "$snrd" ] && snrd=0
	[ -z "$snru" ] && snru=0

	latnd=$(dbt $latnd)
	latnu=$(dbt $latnu)
	snrd=$(dbt $snrd)
	snru=$(dbt $snru)
	
	echo -n "${snrd},${snru}," >> $OUTPUT_FILE
	echo "${latnd},${latnu}" >> $OUTPUT_FILE
}

#
# Is the line up? Or what state is it in?
#
line_state() {
	local lsg=$(dsl_cmd lsg)
	local ls=$(dsl_val "$lsg" nLineState);
	local s;

	case "$ls" in
		"0x0")		s="not initialized" ;;
		"0x1")		s="exception" ;;
		"0x10")		s="not updated" ;;
		"0xff")		s="idle request" ;;
		"0x100")	s="idle" ;;
		"0x1ff")	s="silent request" ;;
		"0x200")	s="silent" ;;
		"0x300")	s="handshake" ;;
		"0x380")	s="full_init" ;;
		"0x400")	s="discovery" ;;
		"0x500")	s="training" ;;
		"0x600")	s="analysis" ;;
		"0x700")	s="exchange" ;;
		"0x800")	s="showtime_no_sync" ;;
		"0x801")	s="showtime_tc_sync" ;;
		"0x900")	s="fastretrain" ;;
		"0xa00")	s="lowpower_l2" ;;
		"0xb00")	s="loopdiagnostic active" ;;
		"0xb10")	s="loopdiagnostic data exchange" ;;
		"0xb20")	s="loopdiagnostic data request" ;;
		"0xc00")	s="loopdiagnostic complete" ;;
		"0x1000000")	s="test" ;;
		"0xd00")	s="resync" ;;
		"0x3c0")	s="short init entry" ;;
		"")		s="not running daemon"; ls="0xfff" ;;
		*)		s="unknown" ;;
	esac

		
	if [ "$ls" = "0x801" ]; then
		echo -n "UP,$ls:$s," >> $OUTPUT_FILE
	else
		echo -n "DOWN,$ls,$s," >> $OUTPUT_FILE
	fi
}



if [ ! -s $OUTPUT_FILE ]; then
	echo "DATE,LINE,STATUS_MSG,UPTIME(sec),DOWN_BITRATE(bit),UP_BITRATE(bit),DOWN_NOISE(dB),UP_NOISE(dB),DOWN_ATTENUATION(dB),UP_ATTENUATION(dB)" > $OUTPUT_FILE
fi

D=$(date +"%F %T")
echo -n "$D," >> $OUTPUT_FILE

line_state
line_uptime
data_rates
line_data

