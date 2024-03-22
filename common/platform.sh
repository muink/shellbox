#!/bin/bash
# Copyright (C) 2024 Anya Lin
#
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.
#

# return: $OS $ARCH $HOSTNAME
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
	export HOSTNAME="$(hostname)"
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

	if [ "$OS" = "windows" ]; then
		if ! command -v gsudo >/dev/null; then
			downloadTo "https://github.com/gerardog/gsudo/releases/latest/download/gsudo.portable.zip" "/tmp/gsudo.portable.zip" \
				&& unzip -qo "/tmp/gsudo.portable.zip" x64/* -d "$BINADIR/" \
				&& mv "$BINADIR/x64" "$BINADIR/gsudo" >/dev/null
			command -v gsudo >/dev/null && {
				local tmp='gsudo() { WSLENV=WSL_DISTRO_NAME:USER:$WSLENV MSYS_NO_PATHCONV=1 gsudo.exe "$@"; }'
				touch ~/.bashrc
				grep -q "$tmp" ~/.bashrc || echo "$tmp" >> ~/.bashrc
			} || err "Please install \"https://gerardog.github.io/gsudo/\"\n"
		fi
		if ! command -v EnableLoopback.exe >/dev/null; then
			downloadTo "https://github.com/Kuingsmile/uwp-tool/releases/latest/download/EnableLoopback.exe" "$BINADIR/EnableLoopback.exe"
			command -v EnableLoopback.exe >/dev/null || err "Please download \"https://github.com/Kuingsmile/uwp-tool/releases/latest/download/EnableLoopback.exe\" and put to \"$BINADIR/EnableLoopback.exe\"\n"
		fi
	fi
}

# func [unix_path]
getWindowsPath() {
	[ -n "$1" ] && pushd "$1" >/dev/null
	"$CMDSDIR/getcd.cmd"
	[ -n "$1" ] && popd >/dev/null
}

# func <install|uninstall|start|stop|restart|enable|disable|check>
windows_schedule() {
	[ -n "$1" ] || return 1
	local TaskName=ShellBox
	local cfg="${RUNICFG//$WORKDIR\//}"
	local bin="\"$(getWindowsPath "$BINADIR" | sed 's|\\|\\\\|g')\\\\$SINGBOX\""
	local args="run -D \"$(getWindowsPath "$WORKDIR" | sed 's|\\|\\\\|g')\" -c \"${cfg////\\\\}\""

	local rcode=$(gsudo schtasks /Query /TN "$TaskName" >/dev/null 2>&1 || echo $?)
	_start() { gsudo schtasks /Query /TN "$TaskName" /FO list | grep -q '^Status:\s*Running' || gsudo schtasks /Run /TN "$TaskName"; sleep 3; }
	_stop()  { gsudo schtasks /Query /TN "$TaskName" /FO list | grep -q '^Status:\s*Running' && gsudo schtasks /End /TN "$TaskName"; sleep 3; }
	_enable()  { gsudo schtasks /Query /TN "$TaskName" /FO list | grep -q '^Status:\s*Disabled' && gsudo schtasks /Change /ENABLE  /TN "$TaskName"; }
	_disable() { gsudo schtasks /Query /TN "$TaskName" /FO list | grep -q '^Status:\s*Disabled' || gsudo schtasks /Change /DISABLE /TN "$TaskName"; }
	_delete() { [ -z "$rcode" ] && { _stop; gsudo schtasks /Delete /TN "$TaskName" /F; } }
	_checkProcess() { tasklist | grep -qi "$SINGBOX" && logs yeah "windows_schedule: Task is runing.\n"; }
	_killProcess()  { tasklist | grep -qi "$SINGBOX" && taskkill /F /IM "$SINGBOX" >/dev/null; }

	case "$1" in
		install)
			_killProcess
			cp -f "$CMDSDIR/task.xml" "/tmp/task.xml"
			sed -i \
				"s|<Command><bin></Command>|<Command>$bin</Command>|
				;s|<Arguments><args></Arguments>|<Arguments>$args</Arguments>|" \
				"/tmp/task.xml"
			pushd /tmp >/dev/null
			gsudo schtasks /Create /XML task.xml /TN "$TaskName" /F
			popd >/dev/null
			gsudo schtasks /Run /TN "$TaskName"
			sleep 3
			_checkProcess
		;;
		uninstall)
			_delete
			_killProcess
		;;
		start) [ -z "$rcode" ] || { logs err "windows_schedule: Task not installed.\n"; return 1; } && _start;;
		stop) [ -z "$rcode" ] && _stop;;
		restart)
			_stop
			_killProcess
			_start
		;;
		enable) [ -z "$rcode" ] && _enable;;
		disable) [ -z "$rcode" ] && _disable;;
		check) [ -z "$rcode" ] && _checkProcess;;
	esac
}

# func <target>
windows_mkrun() {
	[ -n "$1" ] || return 1
	local cfg="${RUNICFG//$WORKDIR\//}"

	cat <<- EOF > "$1"
	@chcp 65001 >nul
	@echo off
	"$(getWindowsPath "$BINADIR")\\$SINGBOX" run -D "$(getWindowsPath "$WORKDIR")" -c "${cfg////\\}"
	EOF
}

# func <install|uninstall>
windows_startup() {
	[ -n "$1" ] || return 1

	case "$1" in
		install)
			windows_mkrun ~/AppData/Roaming/Microsoft/Windows/Start\ Menu/Programs/Startup/shellbox.bat
		;;
		uninstall)
			rm -f ~/AppData/Roaming/Microsoft/Windows/Start\ Menu/Programs/Startup/shellbox.bat 2>/dev/null
		;;
	esac
}

# func
windows_mkdash() {
	local clash_api="$(jq -rc '.experimental.clash_api//""' "$RUNICFG")"
	local host="$(jsonSelect clash_api '.external_controller')"
	[ -n "$host" ] || return 0

	local hostname="$(echo "${host%:*}" | tr -d '[]')"
	if echo "$hostname" | grep -qE "^::1?$"; then hostname='127.0.0.1'; fi
	local port="${host##*:}"
	local secret="$(jsonSelect clash_api '.secret')"

	_mkurl() {
		cat <<- EOF
		[InternetShortcut]
		URL=$1
		EOF
	}

	_mkurl "http://${hostname}:${port}/ui/" > dashboard.url
	_mkurl "http://yacd.metacubex.one/?hostname=${hostname}&port=${port}&secret=${secret}" > yacd.url
	_mkurl "http://clash.metacubex.one/?host=${hostname}&port=${port}&secret=${secret}" > razord.url
}

# func <install|uninstall|start|stop|restart|enable|disable|check>
darwin_daemon() {
	[ -n "$1" ] || return 1
	local ServiceName='shellbox.service'
	local cfg="${RUNICFG//$WORKDIR\//}"
	local plist="/Library/LaunchDaemons/$ServiceName.plist"

	local rcode=$(sudo launchctl list | grep -q "$ServiceName" || echo $?)
	_start() { sudo launchctl   load "$plist"; sleep 3; }
	_stop()  { sudo launchctl unload "$plist"; sleep 3; }
	_enable()  { sudo launchctl   load -w "$plist"; }
	_disable() { sudo launchctl unload -w "$plist"; }
	_checkProcess() { pgrep -f "$SINGBOX" >/dev/null && logs yeah "darwin_daemon: Service is runing.\n"; }
	_killProcess()  { sudo killall "$SINGBOX" 2>/dev/null; }

	case "$1" in
		install)
			_killProcess
			cat <<- EOF > "/tmp/$ServiceName"
				<?xml version="1.0" encoding="UTF-8"?>
				<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
				<plist version="1.0">
				  <dict>
				    <key>Label</key>
				    <string>$ServiceName</string>
				    <key>ProgramArguments</key>
				    <array>
				      <string>$BINADIR/$SINGBOX</string>
				      <string>run</string>
				      <string>-D</string>
				      <string>$WORKDIR</string>
				      <string>-c</string>
				      <string>${cfg////\\}</string>
				    </array>
				    <key>RunAtLoad</key>
				    <true/>
				    <key>KeepAlive</key>
				    <dict>
				      <key>SuccessfulExit</key>
				      <false/>
				    </dict>
				  </dict>
				</plist>
			EOF
			sudo cp -f "/tmp/$ServiceName" "$plist"
			sudo chmod 644 "$plist"
			sudo launchctl load -w "$plist"
			sleep 3
			_checkProcess
		;;
		uninstall)
			_killProcess
			[ -z "$rcode" ] && {
				sudo launchctl unload "$plist"
				sudo rm -f "$plist"
			}
		;;
		start) [ -f "$plist" ] || { logs err "darwin_daemon: Service not installed.\n"; return 1; } && _start;;
		stop) [ -z "$rcode" ] && _stop;;
		restart)
			_stop
			_killProcess
			_start
		;;
		enable) [ -f "$plist" ] && _enable;;
		disable) [ -z "$rcode" ] && _disable;;
		check) [ -z "$rcode" ] && _checkProcess;;
	esac
}

# func <target>
darwin_mkrun() {
	[ -n "$1" ] || return 1
	local cfg="${RUNICFG//$WORKDIR\//}"

	cat <<- EOF > "$1"
	#!/bin/bash
	"$BINADIR/$SINGBOX" run -D "$WORKDIR" -c "$cfg"
	EOF
	chmod +x "$1"
}

# func <install|uninstall> <target>
darwin_startup() {
	# ref:
	# https://apple.stackexchange.com/questions/310495/can-login-items-be-added-via-the-command-line-in-high-sierra
	# https://apple.stackexchange.com/questions/418423/how-to-delete-hidden-login-iterms-from-backgrounditems-btm-cml-way-is-prefered
	#osascript -e 'tell application "System Events" to get the name of every login item'
	#osascript -e 'tell application "System Events" to delete login item "name"'
	[ -n "$1" -a -n "$2" ] || return 1
	local dir="$(cd $(dirname "$2"); pwd | sed 's|/*$|/|')"
	local file="$(basename "$2")"

	case "$1" in
		install)
			osascript -e 'tell application "System Events" to make login item at end with properties {path:"'"$dir$file"'", hidden:false}'
		;;
		uninstall)
			osascript -e 'tell application "System Events" to delete login item "'"$file"'"' 2>/dev/null
		;;
	esac
}

# func <install|uninstall|start|stop|restart|enable|disable|check>
linux_daemon() {
	[ -n "$1" ] || return 1
	ls -l /sbin/init | grep -q "systemd" || { logs err "linux_daemon: SysV is not supported.\n"; return 1; }
	local ServiceName='shellbox'
	local cfg="${RUNICFG//$WORKDIR\//}"
	local service="/etc/systemd/system/$ServiceName.service"

	[ "$(systemctl status "$ServiceName" >/dev/null 2>&1 || echo $?)" = "4" ] && local rcode=4
	_start() { systemctl start "$ServiceName"; sleep 3; }
	_stop()  { systemctl  stop "$ServiceName"; sleep 3; }
	_enable()  { sudo systemctl  enable "$ServiceName"; }
	_disable() { sudo systemctl disable "$ServiceName"; }
	_checkProcess() { pgrep -f "$SINGBOX" >/dev/null && logs yeah "linux_daemon: Service is runing.\n"; }
	_killProcess()  { sudo killall "$SINGBOX" 2>/dev/null; }

	case "$1" in
		install)
			_killProcess
			cat <<- EOF > "/tmp/$ServiceName"
				[Unit]
				Description=ShellBox, a lightweight sing-box client base on shell/bash
				After=network.target nss-lookup.target network-online.target
				
				[Service]
				CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
				AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
				ExecStart="$BINADIR/$SINGBOX" run -D "$WORKDIR" -c "${cfg////\\}"
				ExecReload=/bin/kill -HUP \$MAINPID
				Restart=on-failure
				RestartSec=10s
				LimitNOFILE=infinity
				
				[Install]
				WantedBy=multi-user.target
			EOF
			sudo cp -f "/tmp/$ServiceName" "$service"
			sudo chmod 644 "$service"
			_enable
			_start
			_checkProcess
		;;
		uninstall)
			_killProcess
			[ -z "$rcode" ] && {
				_stop
				_disable
				sudo rm -f "$service"
			}
		;;
		start) [ -z "$rcode" ] || { logs err "linux_daemon: Service not installed.\n"; return 1; } && _start;;
		stop) [ -z "$rcode" ] && _stop;;
		restart)
			_stop
			_killProcess
			_start
		;;
		enable) [ -z "$rcode" ] && _enable;;
		disable) [ -z "$rcode" ] && _disable;;
		check) [ -z "$rcode" ] && _checkProcess;;
	esac
}

# func <target>
linux_mkrun() {
	[ -n "$1" ] || return 1
	local cfg="${RUNICFG//$WORKDIR\//}"

	cat <<- EOF > "$1"
	[Desktop Entry]
	Encoding=UTF-8
	Type=Application
	Name=ShellBox
	Comment=A lightweight sing-box client
	Exec="$BINADIR/$SINGBOX" run -D "$WORKDIR" -c "$cfg"
	Icon="$MAINDIR/docs/assets/logo.png"
	Terminal=true
	Categories=Development;
	EOF
}

# func <install|uninstall>
linux_startup() {
	[ -n "$1" ] || return 1

	case "$1" in
		install)
			grep -q "$SINGBOX" /etc/crontab || sudo sed -i "\$a\\@reboot root sleep 10s; \"$BINADIR/$SINGBOX\" run -D \"$WORKDIR\" -c \"$cfg\"" /etc/crontab
		;;
		uninstall)
			grep -q "$SINGBOX" /etc/crontab && sudo sed -i "/$SINGBOX/d" /etc/crontab
		;;
	esac
}

# func
linux_mkdash() {
	local clash_api="$(jq -rc '.experimental.clash_api//""' "$RUNICFG")"
	local host="$(jsonSelect clash_api '.external_controller')"
	[ -n "$host" ] || return 0

	local hostname="$(echo "${host%:*}" | tr -d '[]')"
	if echo "$hostname" | grep -qE "^::1?$"; then hostname='127.0.0.1'; fi
	local port="${host##*:}"
	local secret="$(jsonSelect clash_api '.secret')"

	_mkurl() {
		cat <<- EOF
		[Desktop Entry]
		Encoding=UTF-8
		Type=Link
		Name=$2
		Icon=text-html
		URL=$1
		EOF
	}

	_mkurl "http://${hostname}:${port}/ui/" Dashboard > dashboard.desktop
	_mkurl "http://yacd.metacubex.one/?hostname=${hostname}&port=${port}&secret=${secret}" Yacd > yacd.desktop
	_mkurl "http://clash.metacubex.one/?host=${hostname}&port=${port}&secret=${secret}" Razord > razord.desktop
}

randomUUID() {
	case "$OS" in
		windows) powershell -c '[guid]::NewGuid('').ToString()';;
		darwin) uuidgen | tr 'A-Z' 'a-z';;
		linux) cat /proc/sys/kernel/random/uuid;;
	esac
}

getDefaultIfname() {
	# ref:
	# https://unix.stackexchange.com/questions/14961/how-to-find-out-which-interface-am-i-using-for-connecting-to-the-internet
	# https://unix.stackexchange.com/questions/473803/how-to-find-out-the-interface-which-is-being-used-for-internet
	# https://unix.stackexchange.com/questions/166999/how-to-display-the-ip-address-of-the-default-interface-with-internet-connection
	# https://fasterthanli.me/series/making-our-own-ping/part-7
	# https://stackoverflow.com/questions/22367173/get-default-gateway-from-batch-file
	# https://stackoverflow.com/questions/8978670/what-do-windows-interface-names-look-like

	case "$OS" in
		windows)
			#wmic Path Win32_IP4RouteTable Where "Destination='0.0.0.0'" Get InterfaceIndex | sed '1d'
			#netsh interface ipv4 show interface
			"$CMDSDIR/getifname.cmd" "$(route -4 print '0.*' | grep '0\.0\.0\.0' | awk '{print $5,$4}' | sort -n | head -n1 | awk '{print $2}')"
		;;
		darwin)
			route -n get default | awk '/interface:/{print $NF}'
		;;
		linux)
			ip route show default | sed -En 's|.+ dev (\S+) .+ metric ([0-9]+)|\2 \1|p' | sort -n | head -n1 | awk '{print $2}'
			#route -n | awk '/^(default|0\.0\.0\.0)/{print $5,$8}' | sort -n | head -n1 | awk '{print $2}' # need net-tools
		;;
	esac
}
