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

DEPENDENCIES="curl unzip tar jq"

# Main program
MAINDIR="$(cd $(dirname $0); pwd)"
BINADIR="$MAINDIR/bin"
COMMDIR="$MAINDIR/common"
MAINSET="$MAINDIR/settings.json"

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
[ "$OS" = "darwin" ] && SED=gsed || SED=sed
depCheck || { pause; exit; }


# Menu
while :; do
clear
cat <<- EOF
$LOGO
                     [Menu]

        1. Rebuild configs
        2. Check update
        3. Upgrade shellbox
        4. Upgrade core
      ------------------------------
        x. Exit
=================================================
EOF


echo -ne "Please select: [ ]\b\b"
read -t 60 MENUID
MENUID=${MENUID:-x}
case "$MENUID" in
	2)
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
	3)
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
	4)
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
