#!/bin/bash
# Copyright (C) 2024 Anya Lin
#
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.
#

# func <url>
urldecode() {
	: "${*//+/ }"
	echo -e "${_//%/\\x}"
}

# func <url>
urldecode_params() {
	isEmpty "$1" && echo '{}' && return 0
	strToString "$1" | jq -c 'splits("&|;") | split("=") as [$key, $val] | {$key: $val}' | jq -cs 'add // {}'
}

# func <url>
parseURL() {
	isEmpty "$1" && return 1
	local services='{ "http": 80, "https": 443 }' obj='{}' url="$1" tmp=''

	obj="$(echo "$obj" | jq -c --args '.href=$ARGS.positional[0]' "$url" )"
	# hash / URI fragment    /#(.+)$/
	obj="$(echo "$obj" | jq -c --args '.hash=$ARGS.positional[0]' "$(echo "$url" | $SED -En 's|.*#(.+)$|\1|p')" )"
	url="${url%%#*}"
	# protocol / URI scheme    /^([[:alpha:]][[:alnum:]\+\-\.]*):/
	obj="$(echo "$obj" | jq -c --args '.protocol=$ARGS.positional[0]' "$(echo "$url" | $SED -En 's|^([[:alpha:]][[:alnum:]\.+-]*):.*|\1|p')" )"
	url="${url#*:}"
	# search / URI query    /\?(.+)$/
	tmp="$(echo "$url" | $SED -En 's|.*\?(.+)$|\1|p')"
	obj="$(echo "$obj" | jq -c --args '.search=$ARGS.positional[0]' "$tmp" )"
	obj="$(echo "$obj" | jq -c --jsonargs '.searchParams=$ARGS.positional[0]' "$(urldecode_params "$tmp" )" )"
	url="${url%%\?*}"
	# ^//    /^\/\//
	url="${url#//}"
	# path    /[^\/]+(\/.+)$/
	obj="$(echo "$obj" | jq -c --args '.path="/"+$ARGS.positional[0]' "$(echo "$url" | $SED -En 's|[^\/]+\/(.+)$|\1|p')" )"
	url="${url%%/*}"
	# userinfo    /^([^@]+)@/
	obj="$(echo "$obj" | jq -c --args '.userinfo=$ARGS.positional[0]' "$(echo "$url" | $SED -En 's|^([^@]+)@.*|\1|p')" )"
	url="${url#*@}"
	# port    /:(\d+)$/
	obj="$(echo "$obj" | jq -c --args '.port=$ARGS.positional[0]' "$(echo "$url" | $SED -En 's|.*:([0-9]+)$|\1|p')" )"
	url="${url%:*}"
	# host
	obj="$(echo "$obj" | jq -c --args '.host=$ARGS.positional[0]' "$(echo "$url" | tr -d '[]')" )"

	isEmpty "$(echo "$obj" | jq '.protocol')" || isEmpty "$(echo "$obj" | jq '.host')" && return 1

	isEmpty "$(echo "$obj" | jq '.port')" && \
		obj="$(echo "$obj" | jq -c --args '.port=$ARGS.positional[0]' "$(echo "$services" | jq --argjson obj "$obj" '.[$obj.protocol]')" )"
	isEmpty "$(echo "$obj" | jq '.port')" && return 1

	tmp="$(echo "$obj" | jq '.userinfo' | StringTostr)"
	if ! isEmpty "$tmp"; then
		# password    /:([^:]+)$/
		obj="$(echo "$obj" | jq -c --args '.password=$ARGS.positional[0]' "$(echo "$tmp" | $SED -En 's|.*:([^:]+)$|\1|p')" )"
		tmp="${tmp%:*}"

		if echo "$tmp" | grep -qE "^[[:alnum:]_\.+-]+$"; then
			obj="$(echo "$obj" | jq -c --args '.username=$ARGS.positional[0]' "$tmp" )"
		else
			obj="$(echo "$obj" | jq -c 'del(.password)' )"
		fi
	fi

	echo "$obj"
}

# func <uri>
parse_uri() {
	local config url params
	local uri="$1" type="${1%%:*}"

	case "$type" in
		http|https)
		;;
		socks|socks4|socks4a|socks5|socks5h)
		;;
		ss)
		;;
		trojan)
		;;
		wireguard)
		;;
		hysteria)
		;;
		hysteria2|hy2)
		;;
		tuic)
		;;
		vless)
		;;
		vmess)
		;;
	esac
}
