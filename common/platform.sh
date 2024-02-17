#!/bin/sh
# Copyright (C) 2024 Anya Lin
#
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.
#

# return: $OS $ARCH
getSysinfo() {
	case "$OSTYPE" in
		linux-gnu)
			# Linux
			export OS=linux
		;;
		darwin*)
			# Mac OSX
			export OS=darwin
		;;
		cygwin)
			# POSIX compatibility layer and Linux environment emulation for Windows
			export OS=windows
		;;
		msys)
			# Lightweight shell and GNU utilities compiled for Windows (part of MinGW)
			export OS=windows
		;;
		*)
			# Unknown.
			unset OS
		;;
	esac
	case "$(uname -m || echo $PROCESSOR_ARCHITECTURE)" in
		x86_64|amd64|AMD64)
			export ARCH=amd64
		;;
		arm64|ARM64|aarch64|AARCH64|armv8*|ARMV8*)
			export ARCH=arm64
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
	local DEPENDENCIES="awk cut date getopt head md5sum mkfifo sed seq sort tail tr wc curl jq tar unzip"
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
						cut|date|head|md5sum|mkfifo|seq|sort|tail|tr|wc)
							err "Missing dependencies: coreutils, Please install manually using the homebrew.\n"
						;;
						sed)
							err "Missing dependencies: gnu-sed, Please install manually using the homebrew.\n"
						;;
						getopt)
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
			#VER=$(wmic os get version | sed -En "/^[0-9\.]+/{s|^([0-9]+\.[0-9]+)\..*|\1|p}")
			if [ "$errcount" -gt 0 ]; then
				for dep in $misss; do
					case "$dep" in
						curl)
							err "Win10+/MinGW64 already includes curl, please upgrade MinGW64 or upgrade your system.\n"
						;;
						awk|cut|date|getopt|head|md5sum|mkfifo|sed|seq|sort|tail|tr|wc|tar|unzip)
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
