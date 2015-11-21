# /usr/bin/env bash

set -e

echo "# $0 $*"

CC="$1"
FLAGS=""
FILE=""
while shift; do
	if [ "${1%%-*}" = "" ]; then
		FLAGS="$FLAGS $1"
	else
		[ -z "$FILE" ] || (echo "timehdr.sh: only one file permitted" && false)
	    	FILE="$1"
	fi
done

if [ -z "$CC" ]; then
	echo "usage: timehdr.sh cc -flags ... file.cpp"
	echo "	for example: timehdr.sh gcc -std=c++11 -fsyntax-only file.cpp"
	exit 1
fi

which "$CC" > /dev/null || (echo "$CC: command not found" && false)

TIMECAT=user	# select the time category: real, user or sys
SAMPLE=3	# how many trial compilations to run for every measurement?
PAR=2		# how many compilations to run in parallel?
SELECT=1,2	# which results to select for averaging? (sed address expression)

RECURSIVE="i guess this is okay"

transaction="/tmp/cpp$$.ii"
indent=0
prev=0
externc=""
marker='|'

measurement () {
	#$CC $FLAGS "$transaction" -o /dev/null
	prev="$elapsed"
	elapsed=$(
		for ((t=1; t<=PAR; t++)); do
		for ((x=t; x<=SAMPLE; x+=PAR)); do
			(time -p $CC $FLAGS "$transaction" -o /dev/null 2> /dev/null) 2>&1 | grep "^$TIMECAT" | tr -cd '[0-9]\n'
		done & done | sort -nk2 | sed -n "${SELECT}s/^0*//p" | awk '{ sum+=$1 } END { print int(0.5+sum/NR) }'
	)
	printf "%6d\t%$((indent*4))s%+d\n" "$elapsed" "" "$((elapsed-prev))"
}

incremental_compilation() {
        while read line; do
                echo "$line" >> "$transaction"
                if [ "${line%%[!#]*}" ]; then
                        line="${line#\# *[\"]}"
                        code="${line##*[\"]}"
                        if [ "${code##\#[! ]*}" = "" ]; then
                                # ignore pragmas and other stuff
                                continue
                        elif [ "${code##*4*}" = "" ]; then
                                externc=yes
                                continue
                        elif [ "${code##*1*}" = "" ]; then
                                hdr="${line%[\"]*}"
                                printf "\t%$((indent*4))s$hdr\n" ""
				if [ "$RECURSIVE" ]; then
				    	# these outer parentheses are very important!
					(indent=$((indent+1)); incremental_compilation)
					measurement
				else
                                	indent=$((indent+1))
				fi
                        elif [ "${code##*2*}" = "" ] && ! [ "$externc" ]; then
                                indent=$((indent-1))
				if [ "$RECURSIVE" ]; then
				   	return
				fi
				measurement
                        fi
                        externc=""
                        #hdr="${line%[\"]*}"
                fi
        done
}

benchmark() {
	printf -- 'total\theader or delta\n'
	printf -- '----\t----\n'
	incremental_compilation
	printf -- '\n'
	printf -- "%d centiseconds total compilation time\n" "$elapsed"
}

rm -f "$transaction"
$CC $FLAGS "$FILE" -o /dev/null
$CC -E "$FILE" | benchmark | sed "s/    /$marker   /g;s/^$marker/ /"
