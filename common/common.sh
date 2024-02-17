#!/bin/bash
# Copyright (C) 2024 Anya Lin
#
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.
#

export CLR_RST='\033[0m'
export CLR_WINK='\033[5m'
export CLR_RED='\033[0;31m'
export CLR_GREEN='\033[0;32m'
export CLR_YELLOW='\033[0;33m'
export CLR_BLUE='\033[0;33m'

# func <msg> [errcode]
err() {
	>&2 echo -ne "${CLR_RED}Error: $1${CLR_RST}"
	return ${2:-1}
}

# func <msg> [errcode]
warn() {
	>&2 echo -ne "${CLR_YELLOW}Warning: $1${CLR_RST}"
	return ${2:-1}
}

# func <msg>
note() {
	echo -ne "Note: $1"
}

# func <msg>
yeah() {
	echo -ne "${CLR_GREEN}$1${CLR_RST}"
}

# func <err|warn|note|yeah> <msg>
logs() {
	[ -n "$ENLOGFILE" ] && { echo -ne "[$(date --iso-8601="seconds")]: $(${1:-note} 2>&1) $2" >> "$MAINLOG"; return 0; }
	${1:-note} "$2"
}

# func <total> <count>
progress() {
	local total=$1 count=$2 block=34 arr=("/" "-" "\\" "|" "/")
	printf "progress:[%-${block}s] %d%% %s\r" "$(head -c$[ $count *$block /$total ] < /dev/zero | tr '\0' '#')" "$[ $count *100 /$total ]" "${arr[$[ $count %4 +1 ]]}"
}

pause() {
	read -p "Press any key to continue..." -n1 -r
}

# func <fdnum>
tmpfd() {
	local tmpfifo=/tmp/pid$$fd$1.fifo
	trap "exec $1>&-;exec $1<&-;exit 0" 2
	mkfifo $tmpfifo
	eval "exec $1<>$tmpfifo"
	rm -rf $tmpfifo
}

# func <fdnum>
unfd() {
	eval "exec $1>&-;exec $1<&-"
}

# func <url> [ua]
wfetch() {
	curl --user-agent "${2:-shellbox}" --connect-timeout 10 --retry 3 -sL --url "$1"
}

# func <url> [target]
downloadTo() {
	curl --progress-bar --connect-timeout 10 --retry 3 -L --url "$1" ${2:+-o "$2"}
}

# func <str>
calcStringMD5() {
	echo -n "$1" | md5sum | awk '{print $1}'
}

# func <str>
decodeBase64Str() {
	echo "$1" | jq -Rrc '@base64d' 2>/dev/null
	#echo "$1" | base64 --decode
}

checkVersion() {
	local new="$(github_getLatest muink shellbox | sed 's|^v||')"
	NEWWVER="${new:-null}"
}

checkCoreVersion() {
	local cur="$($SINGBOX version 2>/dev/null | head -1 | awk '{print $3}')"
	local new="$(github_getLatest sagernet sing-box | sed 's|^v||')"
	CORECURRVER="${cur:-null}"
	CORENEWWVER="${new:-null}"
}

getCoreFeatures() {
	export SBFEATURES="$($SINGBOX version | grep '^Tags:')"
}
