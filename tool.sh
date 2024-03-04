#!/bin/bash
# Copyright (C) 2024 Anya Lin
#
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.
#

VERSION=0.5
LOGO="\
=================================================
          ___ _        _ _ ___              　
         / __| |_  ___| | | _ ) _____ __    　
         \__ \ ' \/ -_) | | _ \/ _ \ \ /    　
         |___/_||_\___|_|_|___/\___/_\_\    　
                                            　
By: Anya Lin$(printf "%$[ 40 - ${#VERSION} ]s" v$VERSION)
================================================="

# Main program
export MAINDIR="$(cd $(dirname $0); pwd)"
export BINADIR="$MAINDIR/bin"
export COMMDIR="$MAINDIR/common"
export CMDSDIR="$MAINDIR/scripts"
export MAINSET="$MAINDIR/settings.json"
export MAINLOG="$MAINDIR/shellbox.log"

# sing-box
export WORKDIR="$MAINDIR/resources"
export CONFDIR="$WORKDIR/configs"
export LOGSDIR="$WORKDIR/logs"
export SUBSDIR="$WORKDIR/providers"
export TEMPDIR="$WORKDIR/templates"
export DASHDIR="$WORKDIR/ui"
export RUNICFG="$WORKDIR/client.json"


export PATH="$BINADIR:$PATH"
. "$COMMDIR/common.sh"
. "$COMMDIR/config.sh"
. "$COMMDIR/github.sh"
. "$COMMDIR/json.sh"
. "$COMMDIR/platform.sh"
. "$COMMDIR/provider.sh"


# Init
[ -d "$BINADIR" ] || mkdir -p "$BINADIR"
[ -f "$MAINSET" ] || echo '{}' > "$MAINSET"
[ -f "$MAINLOG" ] && { [ $(wc -l "$MAINLOG" | awk '{print $1}') -gt 1000 ] && sed -i "1,300d"; }
#
[ -d "$CONFDIR" ] || mkdir -p "$CONFDIR"
[ -d "$LOGSDIR" ] || mkdir -p "$LOGSDIR"
[ -d "$SUBSDIR" ] || mkdir -p "$SUBSDIR"
[ -d "$TEMPDIR" ] || mkdir -p "$TEMPDIR"
[ -d "$DASHDIR" ] || mkdir -p "$DASHDIR"
# ENV
getSysinfo || { pause; exit; }
[ "$OS" = "windows" ] && getWindowsPath >/dev/null
[ "$OS" = "darwin" ] &&
	export PATH="$(brew --prefix)/opt/coreutils/libexec/gnubin:$(brew --prefix)/opt/gnu-sed/libexec/gnubin:$(brew --prefix)/opt/gnu-getopt/bin:$(brew --prefix)/opt/gawk/libexec/gnubin:$PATH"
depCheck || { pause; exit; }
export SINGBOX=shellbox_core$( [ "$OS" = "windows" ] && echo .exe)
[ -x "$(command -v "$SINGBOX")" ] && getCoreFeatures
[ "$OS" = "darwin" ] && export NPROC=$(nproc) ||
	export NPROC=$[ $(cat /proc/cpuinfo | grep "core id" | tr -dc '[0-9]\n' | sort -nu | tail -n1) +1]


# Getargs
GETARGS=$(getopt -n $(basename $0) -o eguVh -l generate,update,setup,version,help -- "$@")
[ "$?" -eq 0 ] || { err "Use the --help option get help\n"; exit; }
eval set -- "$GETARGS"
ERROR=$(echo "$GETARGS" | sed "s|'[^']*'||g;s| -- .*$||;s| --$||")
# Duplicate options
for ru in -h\|--help -V\|--version -e\|-e -g\|--generate -u\|--update --setup\|--setup; do
	eval "echo \"\$ERROR\" | grep -qE \" ${ru%|*}[ .+]* ($ru)| ${ru#*|}[ .+]* ($ru)\"" && { err "Option '$ru' option is repeated\n"; exit; }
done
# Independent options
for ru in -h\|--help -V\|--version; do
	eval "echo \"\$ERROR\" | grep -qE \"^ ($ru) .+|.+ ($ru) .+|.+ ($ru) *\$\"" && { err "Option '$(echo "$ERROR" | sed -E "s,^.*($ru).*$,\1,")' cannot be used with other options\n"; exit; }
done
# Conflicting options


# Subfunc
_help() {
printf "\n\
Usage: $(basename $0) [OPTION]... \n\
\n\
  e.g. $(basename $0) -g          -- Rebuild configs\n\
  e.g. $(basename $0) -V          -- Returns version\n\
\n\
Options:\n\
  -e                       -- Redirect error message to log file\n\
  -g, --generate           -- Rebuild configs\n\
  -u, --update             -- Update subscriptions\n\
  --setup                  -- Setup sing-box\n\
  -V, --version            -- Returns version\n\
  -h, --help               -- Returns help info\n\
\n"
}

_version() {
	local core="$($SINGBOX version 2>/dev/null | head -1 | awk '{print $3}')"
	echo "System: $OS-$ARCH"
	echo "App version: $VERSION"
	echo "Core version: ${core:-null}"
}


# Main
if [ "$#" -gt 1 ]; then
	while [ -n "$1" ]; do
		case "$1" in
			-h|--help)
				_help
				exit
			;;
			-V|--version)
				_version
				exit
			;;
			-e)
				export ENLOGFILE=true
			;;
			-g|--generate)
				GENERATOR=true
			;;
			-u|--update)
				UPDATESUBS=true
			;;
			--setup)
				SETSB=true
			;;
			--)
				shift
				break
			;;
		esac
		shift
	done
	if [ -n "$UPDATESUBS" ]; then updateProvider || exit 1; fi
	if [ -n "$GENERATOR" ];  then buildConfig    || exit 1; fi
	if [ -n "$SETSB" ];      then setSB          || exit 1; fi
	exit
fi
# Menu
while :; do
clear
cat <<- EOF
$LOGO
                     [Menu]

        1. Rebuild configs
        2. Update subscriptions
        3. Check update
        4. Upgrade shellbox
        5. Upgrade core
      ------------------------------
        a. Setup sing-box with current config
        x. Exit
=================================================
EOF


echo -ne "Please select: [ ]\b\b"
read -t 60 MENUID
MENUID=${MENUID:-x}
case "$MENUID" in
	a)
		clear
		cat <<- EOF
		$LOGO

		EOF
		setSB
		pause
	;;
	1)
		clear
		cat <<- EOF
		$LOGO

		EOF
		buildConfig
		pause
	;;
	2)
		clear
		cat <<- EOF
		$LOGO

		EOF
		updateProvider
		pause
	;;
	3)
		checkVersion
		checkCoreVersion
		clear
		cat <<- EOF
		$LOGO
		ShellBox:
		            Current:   $VERSION
		            Latest:    $NEWWVER
		Core:
		            Current:   $CORECURRVER
		            Latest:    $CORENEWWVER
		=================================================
		EOF
		pause
	;;
	4)
		checkVersion
		clear
		cat <<- EOF
		$LOGO

		EOF
		isEmpty "$NEWWVER" && { err "Update check failed.\n\n"; pause; continue; }
		if [ "$VERSION" = "$NEWWVER" ]; then
			yeah "Already the latest, no need to upgrade.\n\n"
		else
			downloadTo "https://codeload.github.com/muink/shellbox/tar.gz/v$NEWWVER" "/tmp/shellbox-$NEWWVER.tar.gz" \
			&& tar -C "/tmp/" -xzf "/tmp/shellbox-$NEWWVER.tar.gz" shellbox-$NEWWVER \
			&& cp -rf "/tmp/shellbox-$NEWWVER/" "$MAINDIR" >/dev/null \
			&& rm -rf "/tmp/shellbox-$NEWWVER" \
			&& yeah "Upgrade completed.\n\n" \
			|| err "Upgrade failed.\n\n" 1
			if [ "$?" = "1" ]; then
				err "Please download gz manually from \"https://github.com/muink/shellbox/releases/tag/v$NEWWVER\" and extract to \"$MAINDIR\"\n" 0
			fi
		fi
		pause
		exec "$0"
	;;
	5)
		checkCoreVersion
		clear
		cat <<- EOF
		$LOGO

		EOF
		isEmpty "$CORENEWWVER" && { err "Update check failed.\n\n"; pause; continue; }
		if [ "$CORECURRVER" = "$CORENEWWVER" ]; then
			yeah "Already the latest, no need to upgrade.\n\n"
		else
			if [ "$OS" = "windows" ]; then
				downloadTo "https://github.com/SagerNet/sing-box/releases/download/v$CORENEWWVER/sing-box-$CORENEWWVER-$OS-$ARCH.zip" "/tmp/sing-box-$CORENEWWVER.zip" \
				&& unzip -qo "/tmp/sing-box-$CORENEWWVER.zip" sing-box-$CORENEWWVER-$OS-$ARCH/sing-box.exe -d "/tmp/" \
				&& mv -f "/tmp/sing-box-$CORENEWWVER-$OS-$ARCH/sing-box.exe" "$BINADIR/$SINGBOX" >/dev/null \
				&& yeah "Upgrade completed.\n\n" \
				|| err "Upgrade failed.\n\n" 1
			else
				downloadTo "https://github.com/SagerNet/sing-box/releases/download/v$CORENEWWVER/sing-box-$CORENEWWVER-$OS-$ARCH.tar.gz" "/tmp/sing-box-$CORENEWWVER.tar.gz" \
				&& tar -C "/tmp/" -xzf "/tmp/sing-box-$CORENEWWVER.tar.gz" sing-box-$CORENEWWVER-$OS-$ARCH/sing-box \
				&& mv -f "/tmp/sing-box-$CORENEWWVER-$OS-$ARCH/sing-box" "$BINADIR/$SINGBOX" >/dev/null \
				&& chmod +x "$BINADIR/$SINGBOX" \
				&& yeah "Upgrade completed.\n\n" \
				|| err "Upgrade failed.\n\n" 1
			fi
			if [ "$?" = "1" ]; then
				err "Please download binary manually from \"https://github.com/SagerNet/sing-box/releases/tag/v$CORENEWWVER\" and put to \"$BINADIR/$SINGBOX\"\n" 0
			fi
			getCoreFeatures
		fi
		pause
	;;
	x) exit;;
	*) continue;;
esac

done
