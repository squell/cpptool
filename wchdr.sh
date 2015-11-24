# /usr/bin/env bash

set -e

AGGREGATE="yes, please"

FLAGS="$1"
FILE="$2"
CC="${3:-gcc}"
if ! shift || ! shift; then
	echo "usage: wcsdir.sh -wc-option file.c [compiler -flag ...]"
	exit 1
fi
shift || true

transaction="/tmp/$$.ii"
indent=0
prev=0
marker='|'

measurement () {
	prev="$count"
	count=$(wc "$FLAGS" < "$transaction")
	printf "%6d\t%$((indent*4))s%+d\n" "$count" "" "$((count-prev))"
}

incremental_count() {
	while read -r line; do
		if [ "${line%%[!#]*}" ]; then
			line="${line#\# *[\"]}"
			code="${line##*[\"]}"
			if [ "${code##\#[! ]*}" = "" ]; then
				# ignore pragmas and other stuff
				continue
			elif [ "${code##*1*}" = "" ]; then
				hdr="${line%[\"]*}"
				printf "\t%$((indent*4))s$hdr\n" ""
				if [ "$AGGREGATE" ]; then
					(indent=$((indent+1)); incremental_count)
				else
					indent=$((indent+1)); incremental_count
				fi
				measurement
			elif [ "${code##*2*}" = "" ]; then
				indent=$((indent-1))
				return
			fi
		else
			echo "$line" >> "$transaction"
		fi
	done
}

statistic() {
	printf -- 'total\theader or delta\n'
	printf -- '----\t----\n'
	echo "$line" > "$transaction"
	incremental_count
}

$CC $@ -E "$FILE" | statistic | sed "s/    /$marker   /g;s/^$marker/ /"
