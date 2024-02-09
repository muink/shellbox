#!/bin/bash
# Copyright (C) 2024 Anya Lin
#
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.
#

strToString() {
	local str
	if [ -z "$1" ]; then
		while read -r -t1 str; do
			echo "$str" | $SED 's|^|"|;s|$|"|'
		done
	else
		echo "$1" | $SED 's|^|"|;s|$|"|'
	fi
}

StringTostr() {
	local str
	if [ -z "$1" ]; then
		while read -r -t1 str; do
			echo "$str" | $SED 's|^"||;s|"$||'
		done
	else
		echo "$1" | $SED 's|^"||;s|"$||'
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

	eval "echo \"\$obj\" | jq -c --args '${filters:-.}' \"\$@\" | jq -rc './/\"\"'"
}

# func <objvar> <filters> [args]
jsonSet() {
	local __tmp
	__tmp="$1=\"\$( echo '${!1}' | jq -c --args '${2:-.}' \"\$@\" )\""
	shift 2

	eval "$__tmp"
}

# func <objvar> <filters> [jsonargs]
jsonSetjson() {
	local __tmp
	__tmp="$1=\"\$( echo '${!1}' | jq -c --jsonargs '${2:-.}' \"\$@\" )\""
	shift 2

	eval "$__tmp"
}

# func <objvar> [inputvar1] [inputvar2] ...
jsonMerge() {
	local __tmp=$1; shift
	__tmp="$__tmp=\"\$( echo $(echo "$@" | $SED 's|\s|" "\$|g;s|^|"\$|;s|$|"|') | jq -nc 'reduce inputs as \$i (null; .+\$i)' )\""

	eval "$__tmp"
}

# func <objvar> [file1] [file1] ...
jsonMergeFiles() {
	local __tmp
	__tmp="$1=\"\$( jq -nc 'reduce inputs as \$i (null; .+\$i)' \"\$@\" )\""
	shift

	eval "$__tmp"
}
