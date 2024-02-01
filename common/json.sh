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
	eval "echo \"\$$1\" | jq -c '${2:-.}' | jq -rc './/\"\"'"
}

# func <objvar> <filters> [args]
jsonSet() {
	local cfg="$1" filters="$2"
	shift 2
	eval "$cfg=\"\$( echo \"\$$cfg\" | jq -c --args '${filters:-.}' \"\$@\" )\""
}

# func <objvar> [inputvar1] [inputvar2] ...
jsonMerge() {
	local cfg="$1"; shift
	local inputs="$(echo "$@" | $SED 's|\s|" "\$|g;s|^|"\$|;s|$|"|')"
	eval "$cfg=\"\$( echo $inputs | jq -nc 'reduce inputs as \$i (null; .+\$i)' )\""
}

# func <objvar> [file1] [file1] ...
jsonMergeFiles() {
	local cfg="$1"; shift
	eval "$cfg=\"\$( jq -nc 'reduce inputs as \$i (null; .+\$i)' \"\$@\" )\""
}
