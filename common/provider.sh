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

# func <rawurl>
urlencode() {
	[ -z "$1" ] && return 0
	echo "$1" | jq -Rr '@uri'
}

# func <url>
urldecode_params() {
	[ -z "$1" ] && echo '{}' && return 0
	echo "$1" | jq -Rc 'splits("&|;") | split("=") as [$key, $val] | {$key: $val}' | jq -sc 'add // {}'
}

# func <obj>
urlencode_params() {
	isEmpty "$1" && return 0
	echo "$1" | jq '. | length as $count | keys_unsorted as $keys | map(.) as $vals | 0 | while(. < $count; .+1) | $keys[.] + "=" + ($vals[.]|tostring)' | jq -src 'join("&")'
}

# func <type> <str>
validation() {
	[ -n "$1" ] && { local type="$1"; } || { err "validation: No type specified.\n"; return 1; }
	[ -n "$2" ] && { local str="$2"; } || { err "validation: String is empty.\n"; return 1; }
	case "$type" in
		features)
			echo "$SBFEATURES" | grep -q "\b$str\b" || return 1
		;;
		host)
			validation hostname "$str" || validation ipaddr4 "$str" || validation ipaddr6 "$str" && return 0
			return 1
		;;
		port)
			[ "$str" -ge 0 -a "$str" -le 65535 ] || return 1
		;;
		hostname)
			[ "${#str}" -le 253 ] || return 1
			echo "$str" | grep -qE "^[[:alnum:]_]+$" && return 0
			echo "$str" | grep -E "^[[:alnum:]_][[:alnum:]_\.-]*[[:alnum:]]$" | grep -qE "[^0-9\.]" && return 0
			return 1
		;;
		ipaddr4)
			echo "$str" | grep -qE "^((25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})$" || return 1
		;;
		ipaddr6)
			echo "$str" | $SED 's|^\[\(.*\)\]$|\1|' | grep -qE "^(\
([[:xdigit:]]{1,4}:){7}[[:xdigit:]]{1,4}|\
([[:xdigit:]]{1,4}:){1,7}:|\
([[:xdigit:]]{1,4}:){1,6}:[[:xdigit:]]{1,4}|\
([[:xdigit:]]{1,4}:){1,5}(:[[:xdigit:]]{1,4}){1,2}|\
([[:xdigit:]]{1,4}:){1,4}(:[[:xdigit:]]{1,4}){1,3}|\
([[:xdigit:]]{1,4}:){1,3}(:[[:xdigit:]]{1,4}){1,4}|\
([[:xdigit:]]{1,4}:){1,2}(:[[:xdigit:]]{1,4}){1,5}|\
[[:xdigit:]]{1,4}:(:[[:xdigit:]]{1,4}){1,6}|\
:((:[[:xdigit:]]{1,4}){1,7}|:)|\
fe80:(:[[:xdigit:]]{0,4}){0,4}%\w+|\
::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})|\
([[:xdigit:]]{1,4}:){1,4}:((25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2}))$" || return 1
		;;
		*)
			err "validation: Invalid type '$type'.\n"
			return 1
		;;
	esac
}

# func <url>
parseURL() {
	isEmpty "$1" && return 1
	local services='{ "http": 80, "https": 443 }' obj='{}' url="$1"
	local protocol userinfo username password host port fpath path search hash

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
	eval "$(echo "$url" | $SED -En "s,^(([^@]+)@)?([[:alnum:]_\.-]+|\[[[:xdigit:]:\.]+\])(:([0-9]+))?(.*),userinfo='\2';host='\3';port='\5';url='\6',p")"
	[ -z "$port" ] && port="$(echo "$services" | jq -r --arg protocol "$protocol" '.[$protocol]')"
	[ -z "$host" -o -z "$port" ] && return 1
	validation host "$host" || return 1
	validation port "$port" || return 1

	if [ -n "$userinfo" ]; then
		# username    /^[[:alnum:]\+\-\_\.]+/
		# password    /^:([^:]+)/
		eval "$(echo "$userinfo" | $SED -En "s|^([[:alnum:]_\.+-]+)(:([^:]+))?.*|username='\1';password='\3'|p")"
	fi

	# path    /^(\/[^\?\#]*)/
	# search / URI query    /^\?([^#]+)/
	eval "$(echo "$url" | $SED -En "s|^(/([^\?#]*))?(\?([^#]+))?.*|fpath='\1';path='\2';search='\4'|p")"
	[ -n "$fpath" ] && path="／$path"

	obj="$(echo "$obj" | jq -c --args \
		'.protocol=$ARGS.positional[0] |
		.host=$ARGS.positional[1] |
		.port=($ARGS.positional[2]|tonumber) |
		.username=$ARGS.positional[3] |
		.password=$ARGS.positional[4] |
		.path=$ARGS.positional[5] |
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

# func <obj>
buildURL() {
	isEmpty "$1" && return 1
	local services='{ "http": 80, "https": 443 }' obj="$1" url=
	local scheme userinfo hostport path query fragment

	scheme="$(jsonSelect obj '.protocol')"
	userinfo="$(jsonSelect obj '.username + if (.password|length) > 0 then ":" + .password else "" end')"
	hostport="$(jsonSelect obj '.host + ":" + (.port|tostring)')"
	path="$(jsonSelect obj '.path' | $SED 's|^／|/|')"
	query="$(urlencode_params "$(jsonSelect obj '.searchParams')" )"
	fragment="$(jsonSelect obj '.hash')"

	echo "$scheme://${userinfo:+$userinfo@}$hostport$path${query:+?$query}${fragment:+#$fragment}"
}

# func <var> <uri>
parse_uri() {
	local config url params
	[ -n "$1" ] && eval "$1=''" || return 1
	local uri="$2" type="${2%%:*}"

	case "$type" in
		http|https)
			url="$(parseURL "$uri")"
			[ -z "$url" ] && { warn "parse_uri: node '$uri' is not a valid format.\n"; return 1; }

			config="$(echo '{}' | jq -c --args \
				'.type="http" |
				.tag=$ARGS.positional[0] |
				.server=$ARGS.positional[1] |
				.server_port=($ARGS.positional[2]|tonumber)' \
				"$(isEmpty "$(jsonSelect url '.hash')" && calcStringMD5 "$uri" || urldecode "$(jsonSelect url '.hash')" )" \
				"$(jsonSelect url '.host')" \
				"$(jsonSelect url '.port')" \
			)"
			# username password
			if ! isEmpty "$(jsonSelect url '.username')"; then
				config="$(echo "$config" | jq -c --args '.username=$ARGS.positional[0]' "$(urldecode "$(jsonSelect url '.username')" )" )"
				isEmpty "$(jsonSelect url '.password')" || \
					config="$(echo "$config" | jq -c --args '.password=$ARGS.positional[0]' "$(urldecode "$(jsonSelect url '.password')" )" )"
			fi
			# path
			isEmpty "$(jsonSelect url '.path')" || \
				config="$(echo "$config" | jq -c --args '.path="/"+$ARGS.positional[0]' "$(jsonSelect url '.path' | $SED 's|^／||')" )"
			# tls
			[ "$type" = "https" ] && \
				config="$(echo "$config" | jq -c '.tls.enabled=true')"
		;;
		hysteria)
		;;
		hysteria2|hy2)
		;;
		socks|socks4|socks4a|socks5|socks5h)
			url="$(parseURL "$uri")"
			[ -z "$url" ] && { warn "parse_uri: node '$uri' is not a valid format.\n"; return 1; }

			config="$(echo '{}' | jq -c --args \
				'.type="socks" |
				.tag=$ARGS.positional[0] |
				.server=$ARGS.positional[1] |
				.server_port=($ARGS.positional[2]|tonumber)' \
				"$(isEmpty "$(jsonSelect url '.hash')" && calcStringMD5 "$uri" || urldecode "$(jsonSelect url '.hash')" )" \
				"$(jsonSelect url '.host')" \
				"$(jsonSelect url '.port')" \
			)"
			# version
			config="$(echo "$config" | jq -c --args '.version=$ARGS.positional[0]' "$(echo "$type" | $SED -En 's,^socks(4a?|5h?)?$,\1,;s|^5h$|5|;s|^$|5|;p')" )"
			# username password
			if ! isEmpty "$(jsonSelect url '.username')"; then
				config="$(echo "$config" | jq -c --args '.username=$ARGS.positional[0]' "$(urldecode "$(jsonSelect url '.username')" )" )"
				isEmpty "$(jsonSelect url '.password')" || \
					config="$(echo "$config" | jq -c --args '.password=$ARGS.positional[0]' "$(urldecode "$(jsonSelect url '.password')" )" )"
			fi
		;;
		ss)
			# https://shadowsocks.org/doc/sip002.html
			url="$(parseURL "$uri")"
			[ -z "$url" ] && { warn "parse_uri: node '$uri' is not a valid format.\n"; return 1; }

			config="$(echo '{}' | jq -c --args \
				'.type="shadowsocks" |
				.tag=$ARGS.positional[0] |
				.server=$ARGS.positional[1] |
				.server_port=($ARGS.positional[2]|tonumber)' \
				"$(isEmpty "$(jsonSelect url '.hash')" && calcStringMD5 "$uri" || urldecode "$(jsonSelect url '.hash')" )" \
				"$(jsonSelect url '.host')" \
				"$(jsonSelect url '.port')" \
			)"
			# method password
			local ss_method ss_passwd
			if ! $(isEmpty "$(jsonSelect url '.username')") && ! isEmpty "$(jsonSelect url '.password')"; then
				ss_method="$(jsonSelect url '.username')"
				ss_passwd="$(urldecode "$(jsonSelect url '.password')" )"
			elif ! isEmpty "$(jsonSelect url '.username')"; then
				local ss_userinfo="\"$(decodeBase64Str "$(urldecode "$(jsonSelect url '.username')" )" )\""
				ss_method="$(jsonSelect ss_userinfo 'split(":")|.[0]')"
				ss_passwd="$(jsonSelect ss_userinfo 'split(":")|.[1]')"
			fi
			config="$(echo "$config" | jq -c --args \
				'.method=$ARGS.positional[0] |
				.password=$ARGS.positional[1]' \
				"$ss_method" \
				"$ss_passwd" \
			)"
			# plugin plugin_opts
			if ! isEmpty "$(jsonSelect url '.searchParams.plugin')"; then
				local ss_pluginfo ss_plugin ss_plugin_opts
				ss_pluginfo="\"$(urldecode "$(jsonSelect url '.searchParams.plugin')" )\""
				ss_plugin="$(jsonSelect ss_pluginfo 'split(";")|.[0]')"
				[ "$ss_plugin" = "simple-obfs" ] && ss_plugin="obfs-local"
				ss_plugin_opts="$(jsonSelect ss_pluginfo 'split(";")|.[1:]|join(";")')"
				config="$(echo "$config" | jq -c --args \
					'.plugin=$ARGS.positional[0] |
					.plugin_opts=$ARGS.positional[1]' \
					"$ss_plugin" \
					"$ss_plugin_opts" \
				)"
			fi
		;;
		trojan)
			# https://p4gefau1t.github.io/trojan-go/developer/url/
			url="$(parseURL "$uri")"
			[ -z "$url" ] && { warn "parse_uri: node '$uri' is not a valid format.\n"; return 1; }
			params="$(jsonSelect url '.searchParams')"

			config="$(echo '{}' | jq -c --args \
				'.type="trojan" |
				.tag=$ARGS.positional[0] |
				.server=$ARGS.positional[1] |
				.server_port=($ARGS.positional[2]|tonumber) |
				.password=$ARGS.positional[3] |
				.tls.enabled=true' \
				"$(isEmpty "$(jsonSelect url '.hash')" && calcStringMD5 "$uri" || urldecode "$(jsonSelect url '.hash')" )" \
				"$(jsonSelect url '.host')" \
				"$(jsonSelect url '.port')" \
				"$(urldecode "$(jsonSelect url '.username')" )" \
			)"
			# tls
			isEmpty "$(jsonSelect params '.sni')" || \
				config="$(echo "$config" | jq -c --args '.tls.server_name=$ARGS.positional[0]' "$(urldecode "$(jsonSelect params '.sni')" )" )"
			# transport
			local trojan_transport_type="$(jsonSelect params '.type')"
			if ! isEmpty "$trojan_transport_type" && [ "$trojan_transport_type" != "tcp" ]; then
				config="$(echo "$config" | jq -c --args '.transport.type=$ARGS.positional[0]' "$trojan_transport_type" )"
				case "$trojan_transport_type" in
					grpc)
						isEmpty "$(jsonSelect params '.serviceName')" || \
							config="$(echo "$config" | jq -c --args '.transport.service_name=$ARGS.positional[0]' "$(urldecode "$(jsonSelect params '.serviceName')" )" )"
					;;
					ws)
						if ! isEmpty "$(jsonSelect params '.path')"; then
							local trojan_transport_depath="$(urldecode "$(jsonSelect params '.path')" )"
							if echo "$trojan_transport_depath" | grep -qE "\?ed="; then
								config="$(echo "$config" | jq -c --args \
									'. as $config |
									$ARGS.positional[0]|split("?ed=") as $data |
									$config |
									.transport.early_data_header_name="Sec-WebSocket-Protocol" |
									.transport.max_early_data=($data[1]|tonumber) |
									.transport.path="/"+$data[0]' \
									"${trojan_transport_depath#/}" \
								)"
							else
								config="$(echo "$config" | jq -c --args '.transport.path="/"+$ARGS.positional[0]' "${trojan_transport_depath#/}" )"
							fi
						fi
					;;
				esac
			fi
		;;
		tuic)
			# https://github.com/daeuniverse/dae/discussions/182
			url="$(parseURL "$uri")"
			[ -z "$url" ] && { warn "parse_uri: node '$uri' is not a valid format.\n"; return 1; }
			params="$(jsonSelect url '.searchParams')"

			if ! validation features 'with_quic'; then
				warn "parse_uri: Skipping unsupported TUIC node '$uri'.\n\tPlease rebuild sing-box with QUIC support!\n"
				return 1
			fi

			config="$(echo '{}' | jq -c --args \
				'.type="tuic" |
				.tag=$ARGS.positional[0] |
				.server=$ARGS.positional[1] |
				.server_port=($ARGS.positional[2]|tonumber) |
				.uuid=$ARGS.positional[3] |
				.tls.enabled=true' \
				"$(isEmpty "$(jsonSelect url '.hash')" && calcStringMD5 "$uri" || urldecode "$(jsonSelect url '.hash')" )" \
				"$(jsonSelect url '.host')" \
				"$(jsonSelect url '.port')" \
				"$(jsonSelect url '.username')" \
			)"
			# password
			isEmpty "$(jsonSelect url '.password')" || \
				config="$(echo "$config" | jq -c --args '.password=$ARGS.positional[0]' "$(urldecode "$(jsonSelect url '.password')" )" )"
			# congestion_control
			isEmpty "$(jsonSelect params '.congestion_control')" || \
				config="$(echo "$config" | jq -c --args '.congestion_control=$ARGS.positional[0]' "$(jsonSelect params '.congestion_control')" )"
			# udp_relay_mode
			isEmpty "$(jsonSelect params '.udp_relay_mode')" || \
				config="$(echo "$config" | jq -c --args '.udp_relay_mode=$ARGS.positional[0]' "$(jsonSelect params '.udp_relay_mode')" )"
			# tls
			isEmpty "$(jsonSelect params '.sni')" || \
				config="$(echo "$config" | jq -c --args '.tls.server_name=$ARGS.positional[0]' "$(urldecode "$(jsonSelect params '.sni')" )" )"
			isEmpty "$(jsonSelect params '.alpn')" || \
				config="$(echo "$config" | jq -c --args \
					'. as $config |
					$ARGS.positional[0]|split(",") as $data |
					$config |
					.tls.alpn=$data' \
					"$(urldecode "$(jsonSelect params '.alpn')" )" \
				)"
		;;
		vless)
		;;
		vmess)
		;;
		wireguard)
		;;
		*)
			warn "parse_uri: node '$uri' is not supported.\n"
			return 1
		;;
	esac

	if ! isEmpty "$config"; then
		isEmpty "$(jsonSelect config '.server')" || \
			config="$(echo "$config" | jq -c --args '.server=$ARGS.positional[0]' "$(jsonSelect config '.server' | tr -d '[]')" )"
	fi

	eval "$1=\"\$config\""
}
