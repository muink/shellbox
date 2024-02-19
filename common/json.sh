#!/bin/bash
# Copyright (C) 2024 Anya Lin
#
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.
#

# Ref: https://gist.github.com/muink/b7f506e4f210633d466c5c8e48440384
export JQFUNC_urid='def urid:
	def uni2num:
		if 48 <= . and . <= 57 then . - 48 elif 65 <= . and . <= 70 then . - 55 else . - 87 end;
	def decode:
		def loop($i):
			if $i >= length then empty else 16 * (.[$i+1] | uni2num) + (.[$i+2] | uni2num), loop($i+3) end;
		explode | [loop(0)];
	def utf82uni:
		def loop($i):
			if $i >= length then empty
			elif .[$i] >= 240 then (.[$i+3]-128) + 64*(.[$i+2]-128) + 4096*(.[$i+1]-128) + 262144*(.[$i]-240), loop($i+4)
			elif .[$i] >= 224 then (.[$i+2]-128) + 64*(.[$i+1]-128) + 4096*(.[$i]-224), loop($i+3)
			elif .[$i] >= 192 then (.[$i+1]-128) + 64*(.[$i]-192), loop($i+2)
			else .[$i], loop($i+1)
			end;
		[loop(0)];
	gsub("(?<m>(?:%[[:xdigit:]]{2})+)"; .m | decode | utf82uni | implode);'

export JQFUNC_push='def push($e):
	.[length]=$e;'

export JQFUNC_insert='def insert($i; $e):
	[.[0:$i],[$e],.[$i:]] | add;'

export JQFUNC_insertArray='def insertArray($i; $e):
	[.[0:$i],$e,.[$i:]] | add;'

strToString() {
	local str
	if [ -z "$1" ]; then
		while read -r -t1 str; do
			echo "$str" | sed 's|^|"|;s|$|"|'
		done
	else
		echo "$1" | sed 's|^|"|;s|$|"|'
	fi
}

StringTostr() {
	local str
	if [ -z "$1" ]; then
		while read -r -t1 str; do
			echo "$str" | sed 's|^"||;s|"$||'
		done
	else
		echo "$1" | sed 's|^"||;s|"$||'
	fi
}

# func <val>
isEmpty() {
	[ -z "$1" -o "$1" = '""' -o "$1" = "null" -o "$(echo "$1" | jq '(type|test("^(object|array)$")) and (length == 0)' 2>/dev/null)" = "true" ] || return 1
}

# func <objvar> <filters> [args]
jsonSelect() {
	local obj="${!1}" filters="$2"
	shift 2

	eval "echo \"\$obj\" | jq -c --args '$JQFUNC_insert $JQFUNC_insertArray $JQFUNC_urid ${filters:-.}' \"\$@\" | jq -rc './/\"\"'"
}

# func <objvar> <filters> [args]
jsonSet() {
	local __tmp
	__tmp="$1=\"\$( echo '${!1}' | jq -c --args '$JQFUNC_insert $JQFUNC_insertArray $JQFUNC_urid ${2:-.}' \"\$@\" )\""
	shift 2

	eval "$__tmp"
}

# func <objvar> <filters> [jsonargs]
jsonSetjson() {
	local __tmp
	__tmp="$1=\"\$( echo '${!1}' | jq -c --jsonargs '$JQFUNC_insert $JQFUNC_insertArray $JQFUNC_urid ${2:-.}' \"\$@\" )\""
	shift 2

	eval "$__tmp"
}

# func <objvar> [inputvar1] [inputvar2] ...
jsonMerge() {
	local __tmp=$1; shift
	__tmp="$__tmp=\"\$( echo $(echo "$@" | sed 's|\s|" "\$|g;s|^|"\$|;s|$|"|') | jq -nc 'reduce inputs as \$i (null; .+\$i)' )\""

	eval "$__tmp"
}

# func <objvar> [file1] [file1] ...
jsonMergeFiles() {
	local __tmp
	__tmp="$1=\"\$( jq -nc 'reduce inputs as \$i (null; .+\$i)' \"\$@\" )\""
	shift

	eval "$__tmp"
}
