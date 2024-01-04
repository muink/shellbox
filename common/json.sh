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
	$SED 's|^|"|;s|$|"|'
}

StringTostr() {
	$SED 's|^"||;s|"$||'
}

# func <val>
isEmpty() {
	[ ! "$1" -o "$1" = '""' -o "$1" = "null" -o "$(echo "$1" | jq '(type|test("object|array")) and (length == 0)' 2>/dev/null)" = "true" ] || return 1
}
