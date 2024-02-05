#!/bin/bash
# Copyright (C) 2024 Anya Lin
#
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.
#

VERSION=0.1
LOGO="\
=================================================
          ___ _        _ _ ___              　
         / __| |_  ___| | | _ ) _____ __    　
         \__ \ ' \/ -_) | | _ \/ _ \ \ /    　
         |___/_||_\___|_|_|___/\___/_\_\    　
                                            　
By: Anya Lin$(printf "%$[ 40 - ${#VERSION} ]s" v$VERSION)
================================================="

# Main program
MAINDIR="$(cd $(dirname $0); pwd)"
BINADIR="$MAINDIR/bin"
COMMDIR="$MAINDIR/common"
MAINSET="$MAINDIR/settings.json"
LOGFILE="$MAINDIR/shellbox.log"

# sing-box
WORKDIR="$MAINDIR/resources"
CONFDIR="$WORKDIR/configs"
TEMPDIR="$WORKDIR/templates"


export PATH="$BINADIR:$PATH"
. "$COMMDIR/common.sh"
. "$COMMDIR/json.sh"
. "$COMMDIR/github.sh"


# Init
[ -d "$BINADIR" ] || mkdir -p "$BINADIR"
[ -f "$MAINSET" ] || touch "$MAINSET"
getSysinfo || { pause; exit; }
echo System: $OS-$ARCH
if [ "$OS" = "darwin" ]; then
	SINGBOX=sing-box
	SED=gsed
	MD5=gmd5sum
	DATE=gdate
	GETOPT=ggetopt
elif [ "$OS" = "windows" ]; then
	SINGBOX=sing-box.exe
	SED=sed.exe
	MD5=md5sum.exe
	DATE=date.exe
	GETOPT=getopt.exe
else
	SINGBOX=sing-box
	SED=sed
	MD5=md5sum
	DATE=date
	GETOPT=getopt
fi
DEPENDENCIES="curl unzip tar jq $SED $MD5 $DATE $GETOPT"
depCheck || { pause; exit; }
SBFEATURES="$($SINGBOX version | grep '^Tags:')"


# Getargs
GETARGS=$($GETOPT -n $(basename $0) -o gVhu -l update,generate,version,help -- "$@")
[ "$?" -eq 0 ] || { err "Use the --help option get help\n"; exit; }
eval set -- "$GETARGS"
ERROR=$(echo "$GETARGS" | sed "s|'[^']*'||g;s| -- .*$||;s| --$||")
# Duplicate options
for ru in -h\|--help -V\|--version -g\|--generate -u\|--update; do
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
  -g, --generate           -- Rebuild configs\n\
  -u, --update             -- Update subscriptions\n\
  -V, --version            -- Returns version\n\
  -h, --help               -- Returns help info\n\
\n"
}

_version() {
	local core="$($SINGBOX version 2>/dev/null | head -1 | awk '{print $3}')"
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
			-g|--generate)
				GENERATOR=true
			;;
			-u|--update)
				UPDATESUBS=true
			;;
			--)
				shift
				break
			;;
		esac
		shift
	done
	if [ -n "$UPDATESUBS" ]; then
		pause
	fi
	if [ -n "$GENERATOR" ]; then
		pause
	fi
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
        x. Exit
=================================================
EOF


echo -ne "Please select: [ ]\b\b"
read -t 60 MENUID
MENUID=${MENUID:-x}
case "$MENUID" in
	1)
		clear
		cat <<- EOF
		$LOGO

		EOF
		pause
	;;
	2)
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
		core:
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
		exit
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
			#pgrep -f "$BINADIR/sing-box(.exe)"
			if [ "$OS" = "windows" ]; then
				downloadTo "https://github.com/SagerNet/sing-box/releases/download/v$CORENEWWVER/sing-box-$CORENEWWVER-$OS-$ARCH.zip" "/tmp/sing-box-$CORENEWWVER.zip" \
				&& unzip -qo "/tmp/sing-box-$CORENEWWVER.zip" sing-box-$CORENEWWVER-$OS-$ARCH/sing-box.exe -d "/tmp/" \
				&& mv -f "/tmp/sing-box-$CORENEWWVER-$OS-$ARCH/sing-box.exe" "$BINADIR/sing-box.exe" >/dev/null \
				&& yeah "Upgrade completed.\n\n" \
				|| err "Upgrade failed.\n\n" 1
			else
				downloadTo "https://github.com/SagerNet/sing-box/releases/download/v$CORENEWWVER/sing-box-$CORENEWWVER-$OS-$ARCH.tar.gz" "/tmp/sing-box-$CORENEWWVER.tar.gz" \
				&& tar -C "/tmp/" -xzf "/tmp/sing-box-$CORENEWWVER.tar.gz" sing-box-$CORENEWWVER-$OS-$ARCH/sing-box \
				&& mv -f "/tmp/sing-box-$CORENEWWVER-$OS-$ARCH/sing-box" "$BINADIR/sing-box" >/dev/null \
				&& chmod +x "$BINADIR/sing-box" \
				&& yeah "Upgrade completed.\n\n" \
				|| err "Upgrade failed.\n\n" 1
			fi
			if [ "$?" = "1" ]; then
				err "Please download binary manually from \"https://github.com/SagerNet/sing-box/releases/tag/v$CORENEWWVER\" and put to \"$BINADIR/sing-box\"\n" 0
			fi
		fi
		pause
	;;
	x) exit;;
	*) continue;;
esac

done
