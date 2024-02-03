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
	local services='{"http":80,"https":443,"hysteria2":443,"hy2":443}' obj='{}' url="$1"
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
	local config='{}' url params
	[ -n "$1" ] && eval "$1=''" || return 1
	local uri="$2" type="${2%%:*}"

	case "$type" in
		http|https)
			url="$(parseURL "$uri")"
			[ -z "$url" ] && { warn "parse_uri: node '$uri' is not a valid format.\n"; return 1; }

			jsonSet config \
				'.type="http" |
				.tag=$ARGS.positional[0] |
				.server=$ARGS.positional[1] |
				.server_port=($ARGS.positional[2]|tonumber)' \
				"$(isEmpty "$(jsonSelect url '.hash')" && calcStringMD5 "$uri" || urldecode "$(jsonSelect url '.hash')" )" \
				"$(jsonSelect url '.host')" \
				"$(jsonSelect url '.port')"
			# username password
			if ! isEmpty "$(jsonSelect url '.username')"; then
				jsonSet config '.username=$ARGS.positional[0]' "$(urldecode "$(jsonSelect url '.username')" )"
				isEmpty "$(jsonSelect url '.password')" || \
					jsonSet config '.password=$ARGS.positional[0]' "$(urldecode "$(jsonSelect url '.password')" )"
			fi
			# path
			isEmpty "$(jsonSelect url '.path')" || \
				jsonSet config '.path="/"+$ARGS.positional[0]' "$(jsonSelect url '.path' | $SED 's|^／||')"
			# tls
			[ "$type" = "https" ] && \
				jsonSet config '.tls.enabled=true'
		;;
		hysteria)
			# https://v1.hysteria.network/docs/uri-scheme/
			url="$(parseURL "$uri")"
			[ -z "$url" ] && { warn "parse_uri: node '$uri' is not a valid format.\n"; return 1; }
			params="$(jsonSelect url '.searchParams')"

			if ! validation features 'with_quic' || [ -n "$(jsonSelect params '.protocol')" -a "$(jsonSelect params '.protocol')" != "udp" ]; then
				if validation features 'with_quic'; then
					warn "parse_uri: Skipping unsupported hysteria node '$uri'.\n"
					return 1
				else
					warn "parse_uri: Skipping unsupported hysteria node '$uri'.\n\tPlease rebuild sing-box with QUIC support!\n"
					return 1
				fi
			fi

			jsonSet config \
				'.type="hysteria" |
				.tag=$ARGS.positional[0] |
				.server=$ARGS.positional[1] |
				.server_port=($ARGS.positional[2]|tonumber) |
				.up_mbps=($ARGS.positional[3]|tonumber) |
				.down_mbps=($ARGS.positional[4]|tonumber) |
				.tls.enabled=true' \
				"$(isEmpty "$(jsonSelect url '.hash')" && calcStringMD5 "$uri" || urldecode "$(jsonSelect url '.hash')" )" \
				"$(jsonSelect url '.host')" \
				"$(jsonSelect url '.port')" \
				"$(jsonSelect params '.upmbps')" \
				"$(jsonSelect params '.downmbps')"
			# auth_str
			isEmpty "$(jsonSelect params '.auth')" || \
				jsonSet config '.auth_str=$ARGS.positional[0]' "$(urldecode "$(jsonSelect params '.auth')" )"
			# obfs
			isEmpty "$(jsonSelect params '.obfsParam')" || \
				jsonSet config '.obfs=$ARGS.positional[0]' "$(urldecode "$(jsonSelect params '.obfsParam')" )"
			# tls
			isEmpty "$(jsonSelect params '.peer')" || \
				jsonSet config '.tls.server_name=$ARGS.positional[0]' "$(urldecode "$(jsonSelect params '.peer')" )"
			isEmpty "$(jsonSelect params '.insecure')" || \
				jsonSet config '.tls.insecure=($ARGS.positional[0]|(. == "1" or . == "true"))' "$(jsonSelect params '.insecure')"
			isEmpty "$(jsonSelect params '.alpn')" || \
				jsonSet config '.tls.alpn=$ARGS.positional[0]' "$(jsonSelect params '.alpn')"
		;;
		hysteria2|hy2)
			# https://v2.hysteria.network/docs/developers/URI-Scheme/
			url="$(parseURL "$uri")"
			[ -z "$url" ] && { warn "parse_uri: node '$uri' is not a valid format.\n"; return 1; }
			params="$(jsonSelect url '.searchParams')"

			if ! validation features 'with_quic'; then
				warn "parse_uri: Skipping unsupported hysteria2 node '$uri'.\n\tPlease rebuild sing-box with QUIC support!\n"
				return 1
			fi

			jsonSet config \
				'.type="hysteria2" |
				.tag=$ARGS.positional[0] |
				.server=$ARGS.positional[1] |
				.server_port=($ARGS.positional[2]|tonumber) |
				.tls.enabled=true' \
				"$(isEmpty "$(jsonSelect url '.hash')" && calcStringMD5 "$uri" || urldecode "$(jsonSelect url '.hash')" )" \
				"$(jsonSelect url '.host')" \
				"$(jsonSelect url '.port')"
			# password
			if ! isEmpty "$(jsonSelect url '.username')"; then
				isEmpty "$(jsonSelect url '.password')" && \
					jsonSet config '.password=$ARGS.positional[0]' "$(urldecode "$(jsonSelect url '.username')" )" || \
					jsonSet config '.password=$ARGS.positional[0]' "$(urldecode "$(jsonSelect url '.username'):$(jsonSelect url '.password')" )"
			fi
			# obfs
			isEmpty "$(jsonSelect params '.obfs')" || \
				jsonSet config '.obfs.type=$ARGS.positional[0]' "$(jsonSelect params '.obfs')"
			isEmpty "$(jsonSelect params '.["obfs-password"]')" || \
				jsonSet config '.obfs.password=$ARGS.positional[0]' "$(urldecode "$(jsonSelect params '.["obfs-password"]')" )"
			# tls
			isEmpty "$(jsonSelect params '.sni')" || \
				jsonSet config '.tls.server_name=$ARGS.positional[0]' "$(urldecode "$(jsonSelect params '.sni')" )"
			isEmpty "$(jsonSelect params '.insecure')" || \
				jsonSet config '.tls.insecure=($ARGS.positional[0]|(. == "1"))' "$(jsonSelect params '.insecure')"
		;;
		socks|socks4|socks4a|socks5|socks5h)
			url="$(parseURL "$uri")"
			[ -z "$url" ] && { warn "parse_uri: node '$uri' is not a valid format.\n"; return 1; }

			jsonSet config \
				'.type="socks" |
				.tag=$ARGS.positional[0] |
				.server=$ARGS.positional[1] |
				.server_port=($ARGS.positional[2]|tonumber) |
				.version=$ARGS.positional[3]' \
				"$(isEmpty "$(jsonSelect url '.hash')" && calcStringMD5 "$uri" || urldecode "$(jsonSelect url '.hash')" )" \
				"$(jsonSelect url '.host')" \
				"$(jsonSelect url '.port')" \
				"$(echo "$type" | $SED -En 's,^socks(4a?|5h?)?$,\1,;s|^5h$|5|;s|^$|5|;p')"
			# username password
			if ! isEmpty "$(jsonSelect url '.username')"; then
				jsonSet config '.username=$ARGS.positional[0]' "$(urldecode "$(jsonSelect url '.username')" )"
				isEmpty "$(jsonSelect url '.password')" || \
					jsonSet config '.password=$ARGS.positional[0]' "$(urldecode "$(jsonSelect url '.password')" )"
			fi
		;;
		ss)
			# https://shadowsocks.org/doc/sip002.html
			url="$(parseURL "$uri")"
			[ -z "$url" ] && { warn "parse_uri: node '$uri' is not a valid format.\n"; return 1; }

			jsonSet config \
				'.type="shadowsocks" |
				.tag=$ARGS.positional[0] |
				.server=$ARGS.positional[1] |
				.server_port=($ARGS.positional[2]|tonumber)' \
				"$(isEmpty "$(jsonSelect url '.hash')" && calcStringMD5 "$uri" || urldecode "$(jsonSelect url '.hash')" )" \
				"$(jsonSelect url '.host')" \
				"$(jsonSelect url '.port')"
			# method password
			if isEmpty "$(jsonSelect url '.password')"; then
				jsonSet config \
					'. as $config |
					$ARGS.positional[0]|@base64d|split(":") as $data |
					$config |
					.method=$data[0] |
					.password=$data[1]' \
					"$(urldecode "$(jsonSelect url '.username')" )"
			else
				jsonSet config \
					'.method=$ARGS.positional[0] |
					.password=$ARGS.positional[1]' \
					"$(jsonSelect url '.username')" \
					"$(urldecode "$(jsonSelect url '.password')" )"
			fi
			# plugin plugin_opts
			if ! isEmpty "$(jsonSelect url '.searchParams.plugin')"; then
				jsonSet config \
					'. as $config |
					$ARGS.positional[0]|split(";") as $data |
					$config |
					.plugin=($data[0]|if (. == "simple-obfs") then "obfs-local" else . end) |
					.plugin_opts=($data[1:]|join(";"))' \
					"$(urldecode "$(jsonSelect url '.searchParams.plugin')" )"
			fi
		;;
		trojan)
			# https://p4gefau1t.github.io/trojan-go/developer/url/
			url="$(parseURL "$uri")"
			[ -z "$url" ] && { warn "parse_uri: node '$uri' is not a valid format.\n"; return 1; }
			params="$(jsonSelect url '.searchParams')"

			jsonSet config \
				'.type="trojan" |
				.tag=$ARGS.positional[0] |
				.server=$ARGS.positional[1] |
				.server_port=($ARGS.positional[2]|tonumber) |
				.password=$ARGS.positional[3] |
				.tls.enabled=true' \
				"$(isEmpty "$(jsonSelect url '.hash')" && calcStringMD5 "$uri" || urldecode "$(jsonSelect url '.hash')" )" \
				"$(jsonSelect url '.host')" \
				"$(jsonSelect url '.port')" \
				"$(urldecode "$(jsonSelect url '.username')" )"
			# tls
			isEmpty "$(jsonSelect params '.sni')" || \
				jsonSet config '.tls.server_name=$ARGS.positional[0]' "$(urldecode "$(jsonSelect params '.sni')" )"
			# transport
			local trojan_transport_type="$(jsonSelect params '.type')"
			if ! isEmpty "$trojan_transport_type" && [ "$trojan_transport_type" != "tcp" ]; then
				jsonSet config '.transport.type=$ARGS.positional[0]' "$trojan_transport_type"
				case "$trojan_transport_type" in
					grpc)
						isEmpty "$(jsonSelect params '.serviceName')" || \
							jsonSet config '.transport.service_name=$ARGS.positional[0]' "$(urldecode "$(jsonSelect params '.serviceName')" )"
					;;
					ws)
						if ! isEmpty "$(jsonSelect params '.path')"; then
							local trojan_transport_depath="$(urldecode "$(jsonSelect params '.path')" )"
							if echo "$trojan_transport_depath" | grep -qE "\?ed="; then
								jsonSet config \
									'. as $config |
									$ARGS.positional[0]|split("?ed=") as $data |
									$config |
									.transport.early_data_header_name="Sec-WebSocket-Protocol" |
									.transport.max_early_data=($data[1]|tonumber) |
									.transport.path="/"+$data[0]' \
									"${trojan_transport_depath#/}"
							else
								jsonSet config '.transport.path="/"+$ARGS.positional[0]' "${trojan_transport_depath#/}"
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

			jsonSet config \
				'.type="tuic" |
				.tag=$ARGS.positional[0] |
				.server=$ARGS.positional[1] |
				.server_port=($ARGS.positional[2]|tonumber) |
				.uuid=$ARGS.positional[3] |
				.tls.enabled=true' \
				"$(isEmpty "$(jsonSelect url '.hash')" && calcStringMD5 "$uri" || urldecode "$(jsonSelect url '.hash')" )" \
				"$(jsonSelect url '.host')" \
				"$(jsonSelect url '.port')" \
				"$(jsonSelect url '.username')"
			# password
			isEmpty "$(jsonSelect url '.password')" || \
				jsonSet config '.password=$ARGS.positional[0]' "$(urldecode "$(jsonSelect url '.password')" )"
			# congestion_control
			isEmpty "$(jsonSelect params '.congestion_control')" || \
				jsonSet config '.congestion_control=$ARGS.positional[0]' "$(jsonSelect params '.congestion_control')"
			# udp_relay_mode
			isEmpty "$(jsonSelect params '.udp_relay_mode')" || \
				jsonSet config '.udp_relay_mode=$ARGS.positional[0]' "$(jsonSelect params '.udp_relay_mode')"
			# tls
			isEmpty "$(jsonSelect params '.sni')" || \
				jsonSet config '.tls.server_name=$ARGS.positional[0]' "$(urldecode "$(jsonSelect params '.sni')" )"
			isEmpty "$(jsonSelect params '.alpn')" || \
				jsonSet config '.tls.alpn=($ARGS.positional[0]|split(","))' "$(urldecode "$(jsonSelect params '.alpn')" )"
		;;
		vless)
			# https://github.com/XTLS/Xray-core/discussions/716
			url="$(parseURL "$uri")"
			[ -z "$url" ] && { warn "parse_uri: node '$uri' is not a valid format.\n"; return 1; }
			params="$(jsonSelect url '.searchParams')"

			if [ "$(jsonSelect params '.type')" = "kcp" ]; then
				warn "parse_uri: Skipping unsupported VLESS node '$uri'.\n"
				return 1
			elif [ "$(jsonSelect params '.type')" = "quic" ]; then
				if validation features 'with_quic'; then
					if [ -n "$(jsonSelect params '.quicSecurity')" -a "$(jsonSelect params '.quicSecurity')" != "none" ]; then
						warn "parse_uri: Skipping unsupported VLESS node '$uri'.\n"
						return 1
					fi
				else
					warn "parse_uri: Skipping unsupported VLESS node '$uri'.\n\tPlease rebuild sing-box with QUIC support!\n"
					return 1
				fi
			fi

			jsonSet config \
				'.type="vless" |
				.tag=$ARGS.positional[0] |
				.server=$ARGS.positional[1] |
				.server_port=($ARGS.positional[2]|tonumber) |
				.uuid=$ARGS.positional[3]' \
				"$(isEmpty "$(jsonSelect url '.hash')" && calcStringMD5 "$uri" || urldecode "$(jsonSelect url '.hash')" )" \
				"$(jsonSelect url '.host')" \
				"$(jsonSelect url '.port')" \
				"$(urldecode "$(jsonSelect url '.username')" )"
			local vless_tls_type="$(jsonSelect params '.security')"
			# flow
			if echo "$vless_tls_type" | grep -qE "^(tls|reality)$"; then
				isEmpty "$(jsonSelect params '.flow')" || \
					jsonSet config '.flow=$ARGS.positional[0]' "$(urldecode "$(jsonSelect params '.flow')" )"
			fi
			# tls
			echo "$vless_tls_type" | grep -qE "^(tls|xtls|reality)$" && \
				jsonSet config '.tls.enabled=true'
			isEmpty "$(jsonSelect params '.sni')" || \
				jsonSet config '.tls.server_name=$ARGS.positional[0]' "$(urldecode "$(jsonSelect params '.sni')" )"
			isEmpty "$(jsonSelect params '.alpn')" || \
				jsonSet config '.tls.alpn=($ARGS.positional[0]|split(","))' "$(urldecode "$(jsonSelect params '.alpn')" )"
			if validation features 'with_utls'; then
				isEmpty "$(jsonSelect params '.fp')" || \
					jsonSet config '.tls.utls.enabled=true|.tls.utls.fingerprint=$ARGS.positional[0]' "$(jsonSelect params '.fp')"
			fi
			# reality
			if [ "$vless_tls_type" = "reality" ]; then
				jsonSet config '.reality.enabled=true'
				isEmpty "$(jsonSelect params '.pbk')" || \
					jsonSet config '.reality.public_key=$ARGS.positional[0]' "$(urldecode "$(jsonSelect params '.pbk')" )"
				isEmpty "$(jsonSelect params '.sid')" || \
					jsonSet config '.reality.short_id=$ARGS.positional[0]' "$(jsonSelect params '.sid')"
			fi
			# transport
			local vless_transport_type="$(jsonSelect params '.type')"
			if ! isEmpty "$vless_transport_type" && [ "$vless_transport_type" != "tcp" ]; then
				jsonSet config '.transport.type=$ARGS.positional[0]' "$vless_transport_type"
			fi
			case "$vless_transport_type" in
				grpc)
					isEmpty "$(jsonSelect params '.serviceName')" || \
						jsonSet config '.transport.service_name=$ARGS.positional[0]' "$(urldecode "$(jsonSelect params '.serviceName')" )"
				;;
				tcp|http)
					if [ "$vless_transport_type" = "http" -o "$(jsonSelect params '.headerType')" = "http" ]; then
						isEmpty "$(jsonSelect params '.host')" || \
							jsonSet config '.transport.host=($ARGS.positional[0]|split(","))' "$(urldecode "$(jsonSelect params '.host')" )"
						isEmpty "$(jsonSelect params '.path')" || \
							jsonSet config '.transport.path=$ARGS.positional[0]' "$(urldecode "$(jsonSelect params '.path')" )"
					fi
				;;
				ws)
					if [ "$(jsonSelect config '.tls.enabled')" != "true" ]; then
						isEmpty "$(jsonSelect params '.host')" || \
							jsonSet config '.transport.headers.Host=$ARGS.positional[0]' "$(urldecode "$(jsonSelect params '.host')" )"
					fi
					if ! isEmpty "$(jsonSelect params '.path')"; then
						local vless_transport_depath="$(urldecode "$(jsonSelect params '.path')" )"
						if echo "$vless_transport_depath" | grep -qE "\?ed="; then
							jsonSet config \
								'. as $config |
								$ARGS.positional[0]|split("?ed=") as $data |
								$config |
								.transport.early_data_header_name="Sec-WebSocket-Protocol" |
								.transport.max_early_data=($data[1]|tonumber) |
								.transport.path="/"+$data[0]' \
								"${vless_transport_depath#/}"
						else
							jsonSet config '.transport.path="/"+$ARGS.positional[0]' "${vless_transport_depath#/}"
						fi
					fi
				;;
			esac
		;;
		vmess)
		;;
		wireguard)
		;;
		*)
			warn "parse_uri: Skipping unsupported node '$uri'.\n"
			return 1
		;;
	esac

	if ! isEmpty "$config"; then
		isEmpty "$(jsonSelect config '.server')" || \
			jsonSet config '.server=$ARGS.positional[0]' "$(jsonSelect config '.server' | tr -d '[]')"
	fi

	eval "$1=\"\$config\""
}
