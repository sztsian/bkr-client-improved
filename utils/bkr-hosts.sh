#!/bin/bash

Usage() {
	echo "Usage: [wiki=1] $0 [-o <owner> | [FQDN1 FQDN2 ...]]" >&2
}

_at=`getopt -o hvo: \
	--long help \
	--long owner: \
    -n "$0" -- "$@"`
eval set -- "$_at"
while true; do
	case "$1" in
	-h|--help)   Usage; shift 1; exit 0;;
	-o|--owner)  owner=$2; shift 2;;
	-v) verbose=1; shift 1;;
	--) shift; break;;
	esac
done

owner=${owner:-fs-qe}
hosts="$@"
[ -z "$hosts" ] && {
	hosts=$(bkr list-systems --xml-filter='<system><owner op="==" value="'"$owner"'"/></system>')
}

baseUrl=https://beaker.engineering.redhat.com

hostinfo() {
	local h=$1 wikiIdx=$2
	local sysinfo=$(curl -L -k -s $baseUrl/systems/$h);
	if [[ "$sysinfo" = "System not found" ]]; then
		echo -e "[Warn] System '$h' not found\n"
		return
	fi
	if [[ -n "$verbose" ]]; then
		echo "$h:"
		jq . <<<"$sysinfo"
		return
	fi

	read memory cpu_cores cpu_processors cpu_speed disk_space status loanedTo lasttime t2 _ < \
		<(jq '.|.memory,.cpu_cores,.cpu_processors,.cpu_speed,.disk_space,.status,.current_loan.recipient,.previous_reservation.finish_time' <<<"$sysinfo" | xargs)

	notes=$(jq '.notes[]|select(.deleted == null)|.text' <<<"$sysinfo")
	wikiNote=$(echo "$notes" | sed -rne '/wiki_note: */{p}')
	brokenNote=$(echo "$notes" | sed -rne '/(Broken|Ticket): */{p}')

	if [[ -z "$wikiIdx" ]]; then
		echo $h;
		{
			echo "CPU: ${cpu_cores}/${cpu_processors}:${cpu_speed/.*/}"
			echo "Memory: $memory"
			echo "Condition: $status"
			echo "IdleSince: $lasttime $t2 (more than $((($(date +%s)-$(date +%s --date "$lasttime"))/(3600*24)/7))weeks)"
			[[ -n "$loanedTo" ]] && echo "LoanedTo: $loanedTo"
			[[ -n "$notes" ]] && echo -e "Notes: {\n$notes\n}"
		} | sed 's/^ */  /'
		echo
	else
		echo "||$wikiIdx||[[$baseUrl/view/$h|$h]]||${cpu_cores}/${cpu_processors}:${cpu_speed/.*/}||$memory||${status}||${loanedTo:--}||${wikiNote}||"
	fi
}

#wiki passed by ENV
[[ -n "$wiki" ]] &&
	echo "|| '''Idx''' || '''Hostname''' || '''CPU''' || '''Memory''' || '''Condition''' || '''Loaned''' || '''Notes''' ||"

i=1
for host in $hosts; do
	hostinfo $host ${wiki:+$((i++))}
done
