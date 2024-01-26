#!/bin/sh
# Copyright (C) 2024 Anya Lin
#
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.
#

dotType() {
	jq 'type'
}

dotLength() {
	jq 'length'
}

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
	[ ! "$1" -o "$1" = '""' -o "$1" = "null" -o "$(echo "$1" | jq '(type|test("object|array")) and (length == 0)' 2>/dev/null)" = "true" ] || return 1
}

# func <objvar> [filters]
jsonSelect() {
	eval "echo \"\$$1\" | jq -rc '$2'"
}
