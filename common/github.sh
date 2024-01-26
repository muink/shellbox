#!/bin/sh
# Copyright (C) 2024 Anya Lin
#
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.
#

# func <user> <repo>
github_getLatest() {
	downloadTo "https://api.github.com/repos/$1/$2/releases/latest" | jq '.tag_name' -r
}

# func <user> <repo>
github_getVList() {
	downloadTo "https://api.github.com/repos/$1/$2/releases" | jq '.[].tag_name?' -r | tr -d '\r'
}
