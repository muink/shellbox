#!/bin/sh
# Copyright (C) 2024 Anya Lin
#
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.
#

CLR_RST='\033[0m'
CLR_RED='\033[0;31m'
CLR_GREEN='\033[0;32m'
CLR_YELLOW='\033[0;33m'
CLR_BLUE='\033[0;33m'

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
	[ -n "$ENLOGFILE" ] && { echo -ne "[$($DATE --iso-8601="seconds")]: $(${1:-note} 2>&1) $2" >> "$MAINLOG"; return 0; }
	${1:-note} "$2"
}

pause() {
	read -p "Press any key to continue..." -n1 -r
}

# func <url> [ua]
wfetch() {
	curl --user-agent "${2:-shellbox}" --connect-timeout 10 --retry 3 -sL "$1"
}

# func <url> [target]
downloadTo() {
	curl --progress-bar --connect-timeout 10 --retry 3 -L "$1" ${2:+-o "$2"}
}

# func <str>
calcStringMD5() {
	echo -n "$1" | $MD5 | cut -f1 -d' '
}

# func <str>
decodeBase64Str() {
	echo "$1" | jq -Rrc '@base64d' 2>/dev/null
	#echo "$1" | base64 --decode
}

# return: $OS $ARCH
getSysinfo() {
	case "$OSTYPE" in
		linux-gnu)
			# Linux
			OS=linux
		;;
		darwin*)
			# Mac OSX
			OS=darwin
		;;
		cygwin)
			# POSIX compatibility layer and Linux environment emulation for Windows
			OS=windows
		;;
		msys)
			# Lightweight shell and GNU utilities compiled for Windows (part of MinGW)
			OS=windows
		;;
		*)
			# Unknown.
			unset OS
		;;
	esac
	case "$(uname -m || echo $PROCESSOR_ARCHITECTURE)" in
		x86_64|amd64|AMD64)
			ARCH=amd64
		;;
		arm64|ARM64|aarch64|AARCH64|armv8*|ARMV8*)
			ARCH=arm64
		;;
		*)
			# Unknown.
			unset ARCH
		;;
	esac
	[ -n "$OS" -a -n "$ARCH" ] || err "Unsupported system or architecture.\n"
	[ "$OS" = "windows" -a "$ARCH" = "arm64" ] && err "Unsupported system or architecture.\n"
	return 0
}

depCheck() {
	local dep errcount=0 misss
	for dep in $DEPENDENCIES; do
		if ! command -v $dep >/dev/null; then
			misss=${misss:+$misss }$dep
			let errcount++
		fi
	done

	case "$OSTYPE" in
		linux-gnu)
			if [ "$errcount" -gt 0 ]; then
				err "Missing dependencies: $misss\n\tPlease install manually using the package manager.\n"
			fi
		;;
		darwin*)
			if [ "$errcount" -gt 0 ]; then
				for dep in $misss; do
					case "$dep" in
						gsed|gmd5sum|gdate)
							err "Missing dependencies: coreutils, Please install manually using the homebrew.\n"
						;;
						ggetopt)
							if [ -x "$(brew --prefix)/opt/gnu-getopt/bin/getopt" ]; then
								ln -s "$(brew --prefix)/opt/gnu-getopt/bin/getopt" "$(brew --prefix)/bin/ggetopt"
								let errcount--
							else
								err "Missing dependencies: gnu-getopt, Please install manually using the homebrew.\n"
							fi
						;;
						*)
							err "Missing dependencies: $dep, Please install manually using the homebrew.\n"
						;;
					esac
				done
			fi
		;;
		cygwin)
			if [ "$errcount" -gt 0 ]; then
				err "Missing dependencies: $misss\n\tPlease install manually using the Cygwin setup.\n"
			fi
		;;
		msys)
			#VER=$(wmic os get version | $SED -En "/^[0-9\.]+/{s|^([0-9]+\.[0-9]+)\..*|\1|p}")
			if [ "$errcount" -gt 0 ]; then
				for dep in $misss; do
					case "$dep" in
						curl)
							err "Win10+/MinGW64 already includes curl, please upgrade MinGW64 or upgrade your system.\n"
						;;
						unzip|tar|awk|sed.exe|md5sum.exe|date.exe|getopt.exe)
							err "MinGW64 already includes $dep, Please upgrade MinGW64.\n"
						;;
						jq)
							downloadTo "https://github.com/jqlang/jq/releases/latest/download/jq-windows-amd64.exe" "$BINADIR/jq.exe"
							command -v jq >/dev/null && let errcount-- || err "Please download \"https://github.com/jqlang/jq/releases/latest/download/jq-windows-amd64.exe\" and put to \"$BINADIR/jq.exe\"\n"
						;;
					esac
				done
			fi
		;;
	esac
	[ "$errcount" -le 0 ] || return 1
}

checkVersion() {
	local new="$(github_getLatest muink shellbox | $SED 's|^v||')"
	NEWWVER="${new:-null}"
}

checkCoreVersion() {
	local cur="$($SINGBOX version 2>/dev/null | head -1 | awk '{print $3}')"
	local new="$(github_getLatest sagernet sing-box | $SED 's|^v||')"
	CORECURRVER="${cur:-null}"
	CORENEWWVER="${new:-null}"
}

getCoreFeatures() {
	SBFEATURES="$($SINGBOX version | grep '^Tags:')"
}
