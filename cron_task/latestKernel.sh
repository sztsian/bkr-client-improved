#!/bin/bash
#author: jiyin@redhat.com

mkdir -p /var/cache/kernelnvrDB
pushd /var/cache/kernelnvrDB  >/dev/null

mailTo=fff@redhat.com
mailCc=kkk@redhat.com
kgitDir=/home/yjh/ws/code.repo
VLIST="5 6 7"
DVLIST=$(echo $VLIST|sed -e 's/5/5c 5s/g')
latestKernelF=.latest.kernel
kfList=$(eval echo $latestKernelF{${VLIST// /,}})
#echo $kfList

searchBrewBuild 'kernel-[-.0-9]+el'"[${VLIST// /}]"'$' >.kernelList
test -n "`cat .kernelList`" &&
	for V in ${VLIST}; do
	    L=$(egrep 'kernel-[-.0-9]+el'$V .kernelList | head -n4)
	    #[ -z "$L" ] && { >${latestKernelF}$V.tmp; break; }
	    echo "$L" >${latestKernelF}$V.tmp
	done

for f in $kfList; do
	[ ! -f ${f}.tmp ] && continue
	[ -z "`cat ${f}.tmp`" ] && continue
	[ -f ${f} ] || {
		mv ${f}.tmp ${f}
		continue
	}
	[ -n "$1" ] && {
		echo
		cat ${f}.tmp
		diff -pNur ${f} ${f}.tmp | sed 's/^/\t/'
		rm -f ${f}.tmp
		continue
	}

	v=${f/$latestKernelF/}
	t=${f##*.}; t=${t/$v/}

	available=1
	p=${PWD}/${f}.patch
	diff -pNur $f ${f}.tmp >$p && continue
	grep '^+[^+]' ${p} || continue

	echo >>$p
	echo "#-------------------------------------------------------------------------------" >>$p
	url=https://home.corp.redhat.com/wiki/rhel${v%[cs]}changelog
	url=http://patchwork.lab.bos.redhat.com/status/rhel${v%[cs]}/changelog.html
	echo "#$url" >>$p
	A=(`grep "^+[^+]" $p | sed 's/^[+-]//' | xargs`)
	for ((i=0; i<${#A[@]}; i++)); do
		tagr=${A[i]}
		echo -e "{Info} ${tagr} changelog read from pkg:"
		downloadBrewBuild kernel-${tagr/kernel-/} --arch=src
		[ -f kernel-${tagr/kernel-/}.src.rpm ] || {
			available=0
		}
		LANG=C rpm -qp --changelog kernel-${tagr/kernel-/}.src.rpm >changeLog$v
		\rm kernel-${tagr/kernel-/}.src.rpm

		sed -n "/\*.*\[${tagr/kernel-/}\]/,/^$/{p}" changeLog$v >changeLog
		sed -n '1p;q' changeLog
		grep '^-' changeLog | sort -k2,2
		echo
	done >>$p

	echo -e "\n\n#===============================================================================" >>$p
	echo -e "\n#Generated by cron latestKernelCheck" >>$p
	echo -e "\n#cur:" >>$p; cat $f.tmp >>$p
	echo -e "\n#pre:" >>$p; cat $f     >>$p
	echo -e "\n\n# the Covsan task info:" >>$p; cat Covscan.$v >>$p

	[ $available = 1 ] && {
		sendmail.sh -p '[Notice] ' -t "$mailTo" -c "$mailCc" "$p" ": new RHEL${v} ${t} available"  &>/dev/null
		#cat $p
		mv ${f}.tmp ${f}
	}

	rm -f $p
done

popd  >/dev/null

