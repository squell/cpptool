#! /usr/bin/env bash

set -e

cutoff=""
if [ "-${1#-}" = "$1" ]; then
	cutoff="${1#-}"
	shift
fi

if ! which "$1" > /dev/null; then
	echo "usage: timehdr.sh [-maxdepth] cc -flags ... file.cpp"
	echo "	for example: timehdr.sh gcc -std=c++11 -fsyntax-only file.cpp"
	exit 1
fi

echo "# $0 ${cutoff:+-$cutoff }$*"

CC="$1"
FLAGS=""
FILE=""
shift
for arg; do
	FLAGS="$FLAGS $FILE"
	FILE="$arg"
done

TIMECAT=user	# select the time category: real, user or sys
SAMPLE=3	# how many trial compilations to run for every measurement?
PAR=2		# how many compilations to run in parallel?
SELECT=1,2	# which results to select for averaging? (sed address expression)

transaction="/tmp/timehdr$$.ii"
indent=0
prev=0
marker='|'

test -x "$(which truncate)" || truncate() {
	# fake truncate for systems without GNU coreutils
	ed "$3" <<<EOF
	\$d
	wq
	EOF
}

balance() {
	tr -cd '{}' | sed $':l\ns/{}//g;tl\ny/{/}/'
}

measurement() {
	braces="$(balance < "$transaction")"
	if [ "$braces" ]; then
		echo "$braces" >> "$transaction"
		bytes_added=$(( ${#braces}+1 ))
		measurement
		truncate -s "-${bytes_added}" "$transaction"
		return
	fi
	prev="$elapsed"
	elapsed=$(
		for ((t=1; t<=PAR; t++)); do
		for ((x=t; x<=SAMPLE; x+=PAR)); do
			(time -p $CC $FLAGS "$transaction" -o /dev/null 2> /dev/null || kill -- -$$) 2>&1 | grep "^$TIMECAT" | tr -cd '[0-9]\n'
		done & done | sort -nk2 | sed -n "${SELECT}s/^0*//p" | awk '{ sum+=$1 } END { print int(0.5+sum/NR) }'
	)
}

incremental_compilation() {
	while read -r line; do
		echo "$line" >> "$transaction"
		if [ "${line%%[!#]*}" ]; then
			line="${line#\# *[\"]}"
			code="${line##*[\"]}"
			if [ "${code##\#[! ]*}" = "" ]; then
				# ignore pragmas and other stuff
				continue
			elif [ "${code##*1*}" = "" ]; then
				hdr="${line%[\"]*}"
				[ "$indent" -le "${cutoff:-$indent}" ] || { 
					[ "$1" ] || printf "\t%$((indent*4))s+$hdr\n" ""
					incremental_compilation "wheee"
					continue
				}
				printf "\t%$((indent*4))s$hdr\n" ""
				# these outer parentheses are very important!
				(indent=$((indent+1)); incremental_compilation)
				measurement
				printf "%6d\t%$((indent*4))s%+d\n" "$elapsed" "" "$((elapsed-prev))"
			elif [ "${code##*2*}" = "" ]; then
				return
			fi
		fi
	done
}

benchmark() {
	trap -- 'echo "# $CC $FLAGS $transaction -o /dev/null"; $CC $FLAGS "$transaction" -o /dev/null' TERM
	printf -- 'total\theader or delta\n'
	printf -- '----\t----\n'
	incremental_compilation
	measurement
	printf -- '\n'
	printf -- "%d centiseconds total compilation time\n" "$elapsed"
}

rm -f "$transaction"
{ $CC $FLAGS -E "$FILE" || kill -- -$$; } | benchmark | sed "s/    /$marker   /g;s/^$marker/ /"
rm -f "$transaction"
