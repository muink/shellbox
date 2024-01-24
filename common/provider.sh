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

# func <url>
parseURL2() {
	isEmpty "$1" && return 1
	local services='{ "http": 80, "https": 443 }' obj='{}' url="$1"
	local protocol userinfo username password host port path search hash

	obj="$(echo "$obj" | jq -c --args '.href=$ARGS.positional[0]' "$url" )"
	# hash / URI fragment    /#(.+)$/
	hash="$(echo "$url" | $SED -En 's|.*#(.+)$|\1|p')"
	url="${url%#*}"
	# protocol / URI scheme    /^([[:alpha:]][[:alpha:]\d\+\-\.]*):(//)*/
	eval "$(echo "$url" | $SED -En "s|^([[:alpha:]][[:alnum:]\.+-]*):(//)?(.+)|protocol='\1';url='\3'|p")"
	[ -n "$protocol" ] || return 1
	# userinfo    /^([^@]+)@/
	# host    /^[\w\-\.]+/
	# port    /^:(\d+)/
	eval "$(echo "$url" | $SED -En "s|^(([^@]+)@)?([[:alnum:]_\.-]+)(:([0-9]+))?(.*)|userinfo='\2';host='\3';port='\5';url='\6'|p")"
	host="$(echo "$host" | tr -d '[]')"
	[ -z "$port" ] && port="$(echo "$services" | jq --arg protocol "$protocol" '.[$protocol]')"
	[ -z "$host" ] || isEmpty "$port" && return 1

	if [ -n "$userinfo" ]; then
		# username    /^[[:alnum:]\+\-\_\.]+/
		# password    /^:([^:]+)/
		eval "$(echo "$userinfo" | $SED -En "s|^([[:alnum:]_\.+-]+)(:([^:]+))?|username='\1';password='\3'|p")"
	fi

	# path    /^(\/[^\?\#]*)/
	# search / URI query    /^\?([^#]+)/
	eval "$(echo "$url" | $SED -En "s|^(/([^\?#]*))?(\?([^#]+))?.*|path='\2';search='\4'|p")"

	obj="$(echo "$obj" | jq -c --args \
		'.protocol=$ARGS.positional[0] |
		.host=$ARGS.positional[1] |
		.port=$ARGS.positional[2] |
		.username=$ARGS.positional[3] |
		.password=$ARGS.positional[4] |
		.path="/"+$ARGS.positional[5] |
		.hash=$ARGS.positional[6]' \
		"$protocol" \
		"$host" \
		"$port" \
		"$username" \
		"$password" \
		"$path" \
		"$hash" \
	)"
	obj="$(echo "$obj" | jq -c --jsonargs '.searchParams=$ARGS.positional[0]' "$(urldecode_params "$search" )" )"

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
