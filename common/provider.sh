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
	echo "&$1" | sed -E 's|&([^&=]+)(=([^&]*))?|,"\1":"\3"|g;s|^,|{|;s|$|}|' # DONOT decode params value, sed cannot handle array or object
	#echo "$1" | jq -Rc 'splits("&|;") | split("=") as [$key, $val] | {($key): $val}' | jq -sc 'add // {}'
}

# func <obj>
urlencode_params() {
	isEmpty "$1" && return 0
	echo "$1" | jq '. | length as $count | keys_unsorted as $keys | map(.) as $vals | 0 | while(. < $count; .+1) | $keys[.] + "=" + ($vals[.]|tostring)' | jq -src 'join("&")'
}

# func <type> <str>
validation() {
	[ -n "$1" ] && { local type="$1"; } || { logs err "validation: No type specified.\n"; return 1; }
	[ -n "$2" ] && { local str="$2"; } || { logs err "validation: String is empty.\n"; return 1; }
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
		md5)
			[ "${#str}" -eq 32 ] && echo "$str" | grep -qE "^[[:xdigit:]]+$" || return 1
		;;
		*)
			logs err "validation: Invalid type '$type'.\n"
			return 1
		;;
	esac
}

# func <url>
parseURL() {
	isEmpty "$1" && return 1
	local url="$1"
	local protocol userinfo username password host port fpath path search hash

	# hash / URI fragment    /#(.+)$/
	hash="$(echo "$url" | $SED -En 's|.*#(.+)$|\1|p')"
	url="${url%#*}"
	# protocol / URI scheme    /^([[:alpha:]][[:alpha:]\d\+\-\.]*):\/\//
	eval "$(echo "$url" | $SED -En "s|^([[:alpha:]][[:alnum:]\.+-]*)://(.+)|protocol='\1';url='\2'|p")"
	[ -n "$protocol" ] || return 1
	# userinfo    /^([^@]+)@/
	# host    /^[\w\-\.]+/
	# port    /^:(\d+)/
	eval "$(echo "$url" | $SED -En "s,^(([^@]+)@)?([[:alnum:]_\.-]+|\[[[:xdigit:]:\.]+\])(:([0-9]+))?(.*),userinfo='\2';host='\3';port='\5';url='\6',p")"
	if [ -z "$port" ]; then
		case "$protocol" in
			http) port=80 ;;
			https|hysteria2|hy2) port=443 ;;
		esac
	fi
	[ -z "$host" -o -z "$port" ] && return 1
	validation host "$host" || return 1
	validation port "$port" || return 1

	if [ -n "$userinfo" ]; then
		# https://www.rfc-editor.org/rfc/rfc3986.html#section-3.2.1
		# username    /^[^:]+/
		# password    /^:([^:]+)/
		eval "$(echo "$userinfo" | $SED -En "s|^([^:]+)(:([^:]+))?.*|username='\1';password='\3'|p")"
	fi

	# path    /^(\/[^\?\#]*)/
	# search / URI query    /^\?([^#]+)/
	eval "$(echo "$url" | $SED -En "s|^(/([^\?#]*))?(\?([^#]+))?.*|fpath='\1';path='\2';search='\4'|p")"
	[ -n "$fpath" ] && fpath=true || fpath=false

	# pre-decode
	[ -n "$path" ] && path="$(urldecode "$path")"
	[ -n "$hash" ] && hash="$(urldecode "$hash")" || hash="$(calcStringMD5 "$url")"
	#search

	echo "$(cat <<-EOF
		{
			"protocol": "$protocol",
			"host": "$host",
			"port": $port,
			"username": "$username",
			"password": "$password",
			"fpath": $fpath,
			"path": "$path",
			"hash": "$hash",
			"searchParams": $(urldecode_params "$search" )
		}
	EOF
	)"
}

# func <obj>
buildURL() {
	isEmpty "$1" && return 1
	local services='{ "http": 80, "https": 443 }' obj="$1" url=
	local scheme userinfo hostport path query fragment

	scheme="$(jsonSelect obj '.protocol')"
	userinfo="$(jsonSelect obj '.username + if (.password|length) > 0 then ":" + .password else "" end')"
	hostport="$(jsonSelect obj '.host + ":" + (.port|tostring)')"
	[ -n "$(jsonSelect obj '.fpath')" ] && {
		path="/$(urlencode "$(jsonSelect obj '.path')" )"
	}
	query="$(urlencode_params "$(jsonSelect obj '.searchParams')" )"
	fragment="$(jsonSelect obj '.hash')"
	if validation md5 "$fragment"; then
		unset fragment
	else
		fragment="$(urlencode "$fragment")"
	fi

	echo "$scheme://${userinfo:+$userinfo@}$hostport$path${query:+?$query}${fragment:+#$fragment}"
}

# func <var> <uri>
parse_uri() {
	echo "$1" | grep -qE "^(config|url|params|uri|type|body|ss_body|ss_lable|transport_type|transport_depath|tls_type)$" &&
		{ logs err "parse_uri: Variable name '$1' is conflict.\n"; return 1; }
	local config='{}' url params
	[ -n "$1" ] && eval "$1=''" || return 1
	local uri="$2" type="${2%%:*}" body="$(echo "$2" | $SED -E 's|^([[:alpha:]][[:alnum:]\.+-]*)://||')"

	case "$type" in
		http|https)
			url="$(parseURL "$uri")"
			[ -z "$url" ] && { logs warn "parse_uri: node '$uri' is not a valid format.\n"; return 1; }

			jsonSetjson config \
				'$ARGS.positional[0] as $url
				| .type="http"
				| .tag=$url.hash
				| .server=$url.host
				| .server_port=$url.port
				# username password
				| if ($url.username|type) == "string" and ($url.username|length) > 0 then
					.username=($url.username|urid)
					| if ($url.password|type) == "string" and ($url.password|length) > 0 then
						.password=($url.password|urid)
					else . end
				else . end
				# path
				| if $url.fpath then .path="/"+$url.path else . end
				# tls
				| if $url.protocol == "https" then .tls.enabled=true else . end' \
				"$url"
		;;
		hysteria)
			# https://v1.hysteria.network/docs/uri-scheme/
			url="$(parseURL "$uri")"
			[ -z "$url" ] && { logs warn "parse_uri: node '$uri' is not a valid format.\n"; return 1; }
			params="$(jsonSelect url '.searchParams')"

			if validation features 'with_quic'; then
				if [ "$(jsonSelect params '(.protocol|length) > 0 and .protocol != "udp"')" = "true" ]; then
					logs warn "parse_uri: Skipping unsupported hysteria node '$uri'.\n"
					return 1
				fi
			else
				logs warn "parse_uri: Skipping unsupported hysteria node '$uri'.\n\tPlease rebuild sing-box with QUIC support!\n"
				return 1
			fi

			jsonSetjson config \
				'$ARGS.positional[0] as $url
				| $ARGS.positional[1] as $params
				| .type="hysteria"
				| .tag=$url.hash
				| .server=$url.host
				| .server_port=$url.port
				| .up_mbps=($params.upmbps|tonumber)
				| .down_mbps=($params.downmbps|tonumber)
				# obfs
				| if ($params.obfsParam|length) > 0 then .obfs=($params.obfsParam|urid) else . end
				# auth_str
				| if ($params.auth|length) > 0 then .auth_str=($params.auth|urid) else . end
				# tls
				| .tls.enabled=true
				| if ($params.peer|length) > 0 then .tls.server_name=($params.peer|urid) else . end
				| if ($params.insecure|test("^(1|true)$") ) then .tls.insecure=true else . end
				| if ($params.alpn|length) > 0 then .tls.alpn=$params.alpn else . end' \
				"$url" "$params"
		;;
		hysteria2|hy2)
			# https://v2.hysteria.network/docs/developers/URI-Scheme/
			url="$(parseURL "$uri")"
			[ -z "$url" ] && { logs warn "parse_uri: node '$uri' is not a valid format.\n"; return 1; }
			params="$(jsonSelect url '.searchParams')"

			if ! validation features 'with_quic'; then
				logs warn "parse_uri: Skipping unsupported hysteria2 node '$uri'.\n\tPlease rebuild sing-box with QUIC support!\n"
				return 1
			fi

			jsonSetjson config \
				'$ARGS.positional[0] as $url
				| $ARGS.positional[1] as $params
				| .type="hysteria2"
				| .tag=$url.hash
				| .server=$url.host
				| .server_port=$url.port
				# password
				| if ($url.username|length) > 0 then
					if ($url.password|length) > 0 then
						.password=($url.username + ":" + $url.password | urid)
					else
						.password=($url.username|urid)
					end
				else . end
				# obfs
				| if ($params.obfs|length) > 0 then .obfs.type=$params.obfs else . end
				| if ($params.["obfs-password"]|length) > 0 then .obfs.password=($params.["obfs-password"]|urid) else . end
				# tls
				| .tls.enabled=true
				| if ($params.sni|length) > 0 then .tls.server_name=($params.sni|urid) else . end
				| if $params.insecure == "1" then .tls.insecure=true else . end' \
				"$url" "$params"
		;;
		socks|socks4|socks4a|socks5|socks5h)
			url="$(parseURL "$uri")"
			[ -z "$url" ] && { logs warn "parse_uri: node '$uri' is not a valid format.\n"; return 1; }

			jsonSetjson config \
				'$ARGS.positional[0] as $url
				| .type="socks"
				| .tag=$url.hash
				| .server=$url.host
				| .server_port=$url.port
				| .version=(
					$url.protocol
					| if test("5") then "5"
					elif test("4a") then "4a"
					elif test("4") then "4"
					else "5" end
				)
				# username password
				| if ($url.username|type) == "string" and ($url.username|length) > 0 then
					.username=($url.username|urid)
					| if ($url.password|type) == "string" and ($url.password|length) > 0 then
						.password=($url.password|urid)
					else . end
				else . end' \
				"$url"
		;;
		ss)
			# Shadowrocket format
			local ss_body ss_lable
			eval "$(echo "$body" | $SED -En "s|^([^#]+)(#.*)?|ss_body='\1';ss_lable='\2'|p")"
			ss_body="$(decodeBase64Str "$ss_body")"
			[ -n "$ss_body" ] && uri="$type://$ss_body$ss_lable"

			# https://shadowsocks.org/doc/sip002.html
			url="$(parseURL "$uri")"
			[ -z "$url" ] && { logs warn "parse_uri: node '$uri' is not a valid format.\n"; return 1; }
			params="$(jsonSelect url '.searchParams')"

			jsonSetjson config \
				'$ARGS.positional[0] as $url
				| $ARGS.positional[1] as $params
				| .type="shadowsocks"
				| .tag=$url.hash
				| .server=$url.host
				| .server_port=$url.port
				# method password
				| if ($url.password|length) > 0 then
					.password=($url.password|urid)
					| .method=$url.username
				else
					($url.username | urid | @base64d | split(":")) as $data
					| .method=$data[0]
					| .password=$data[1]
				end
				# plugin plugin_opts
				| if ($params.plugin|length) > 0 then
					($params.plugin | urid | split(";")) as $data
					| .plugin=($data[0] | if . == "simple-obfs" then "obfs-local" else . end)
					| .plugin_opts=($data[1:] | join(";"))
				else . end' \
				"$url" "$params"
		;;
		trojan)
			# https://p4gefau1t.github.io/trojan-go/developer/url/
			url="$(parseURL "$uri")"
			[ -z "$url" ] && { logs warn "parse_uri: node '$uri' is not a valid format.\n"; return 1; }
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
			isEmpty "$(jsonSelect params '.sni')" ||
				jsonSet config '.tls.server_name=$ARGS.positional[0]' "$(urldecode "$(jsonSelect params '.sni')" )"
			# transport
			local transport_type="$(jsonSelect params '.type')"
			if ! isEmpty "$transport_type" && [ "$transport_type" != "tcp" ]; then
				jsonSet config '.transport.type=$ARGS.positional[0]' "$transport_type"
				case "$transport_type" in
					grpc)
						isEmpty "$(jsonSelect params '.serviceName')" ||
							jsonSet config '.transport.service_name=$ARGS.positional[0]' "$(urldecode "$(jsonSelect params '.serviceName')" )"
					;;
					ws)
						isEmpty "$(jsonSelect params '.host')" ||
							jsonSet config '.transport.headers.Host=$ARGS.positional[0]' "$(urldecode "$(jsonSelect params '.host')" )"
						if ! isEmpty "$(jsonSelect params '.path')"; then
							local transport_depath="$(urldecode "$(jsonSelect params '.path')" )"
							if echo "$transport_depath" | grep -qE "\?ed="; then
								jsonSet config \
									'. as $config |
									$ARGS.positional[0]|split("?ed=") as $data |
									$config |
									.transport.early_data_header_name="Sec-WebSocket-Protocol" |
									.transport.max_early_data=($data[1]|tonumber) |
									.transport.path="/"+$data[0]' \
									"${transport_depath#/}"
							else
								jsonSet config '.transport.path="/"+$ARGS.positional[0]' "${transport_depath#/}"
							fi
						fi
					;;
				esac
			fi
		;;
		tuic)
			# https://github.com/daeuniverse/dae/discussions/182
			url="$(parseURL "$uri")"
			[ -z "$url" ] && { logs warn "parse_uri: node '$uri' is not a valid format.\n"; return 1; }
			params="$(jsonSelect url '.searchParams')"

			if ! validation features 'with_quic'; then
				logs warn "parse_uri: Skipping unsupported TUIC node '$uri'.\n\tPlease rebuild sing-box with QUIC support!\n"
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
			isEmpty "$(jsonSelect url '.password')" ||
				jsonSet config '.password=$ARGS.positional[0]' "$(urldecode "$(jsonSelect url '.password')" )"
			# congestion_control
			isEmpty "$(jsonSelect params '.congestion_control')" ||
				jsonSet config '.congestion_control=$ARGS.positional[0]' "$(jsonSelect params '.congestion_control')"
			# udp_relay_mode
			isEmpty "$(jsonSelect params '.udp_relay_mode')" ||
				jsonSet config '.udp_relay_mode=$ARGS.positional[0]' "$(jsonSelect params '.udp_relay_mode')"
			# tls
			isEmpty "$(jsonSelect params '.sni')" ||
				jsonSet config '.tls.server_name=$ARGS.positional[0]' "$(urldecode "$(jsonSelect params '.sni')" )"
			isEmpty "$(jsonSelect params '.alpn')" ||
				jsonSet config '.tls.alpn=($ARGS.positional[0]|split(","))' "$(urldecode "$(jsonSelect params '.alpn')" )"
		;;
		vless)
			# https://github.com/XTLS/Xray-core/discussions/716
			url="$(parseURL "$uri")"
			[ -z "$url" ] && { logs warn "parse_uri: node '$uri' is not a valid format.\n"; return 1; }
			params="$(jsonSelect url '.searchParams')"

			if [ "$(jsonSelect params '.type')" = "kcp" ]; then
				logs warn "parse_uri: Skipping unsupported VLESS node '$uri'.\n"
				return 1
			elif [ "$(jsonSelect params '.type')" = "quic" ]; then
				if validation features 'with_quic'; then
					if [ -n "$(jsonSelect params '.quicSecurity')" -a "$(jsonSelect params '.quicSecurity')" != "none" ]; then
						logs warn "parse_uri: Skipping unsupported VLESS node '$uri'.\n"
						return 1
					fi
				else
					logs warn "parse_uri: Skipping unsupported VLESS node '$uri'.\n\tPlease rebuild sing-box with QUIC support!\n"
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
			local tls_type="$(jsonSelect params '.security')"
			# flow
			if echo "$tls_type" | grep -qE "^(tls|reality)$"; then
				isEmpty "$(jsonSelect params '.flow')" ||
					jsonSet config '.flow=$ARGS.positional[0]' "$(urldecode "$(jsonSelect params '.flow')" )"
			fi
			# tls
			echo "$tls_type" | grep -qE "^(tls|xtls|reality)$" &&
				jsonSet config '.tls.enabled=true'
			isEmpty "$(jsonSelect params '.sni')" ||
				jsonSet config '.tls.server_name=$ARGS.positional[0]' "$(urldecode "$(jsonSelect params '.sni')" )"
			isEmpty "$(jsonSelect params '.alpn')" ||
				jsonSet config '.tls.alpn=($ARGS.positional[0]|split(","))' "$(urldecode "$(jsonSelect params '.alpn')" )"
			if validation features 'with_utls'; then
				isEmpty "$(jsonSelect params '.fp')" ||
					jsonSet config '.tls.utls.enabled=true|.tls.utls.fingerprint=$ARGS.positional[0]' "$(jsonSelect params '.fp')"
			fi
			# reality
			if [ "$tls_type" = "reality" ]; then
				jsonSet config '.reality.enabled=true'
				isEmpty "$(jsonSelect params '.pbk')" ||
					jsonSet config '.reality.public_key=$ARGS.positional[0]' "$(urldecode "$(jsonSelect params '.pbk')" )"
				isEmpty "$(jsonSelect params '.sid')" ||
					jsonSet config '.reality.short_id=$ARGS.positional[0]' "$(jsonSelect params '.sid')"
			fi
			# transport
			local transport_type="$(jsonSelect params '.type')"
			if ! isEmpty "$transport_type" && [ "$transport_type" != "tcp" ]; then
				jsonSet config '.transport.type=$ARGS.positional[0]' "$transport_type"
			fi
			case "$transport_type" in
				grpc)
					isEmpty "$(jsonSelect params '.serviceName')" ||
						jsonSet config '.transport.service_name=$ARGS.positional[0]' "$(urldecode "$(jsonSelect params '.serviceName')" )"
				;;
				tcp|http)
					if [ "$transport_type" = "http" -o "$(jsonSelect params '.headerType')" = "http" ]; then
						isEmpty "$(jsonSelect params '.host')" ||
							jsonSet config '.transport.host=($ARGS.positional[0]|split(","))' "$(urldecode "$(jsonSelect params '.host')" )"
						isEmpty "$(jsonSelect params '.path')" ||
							jsonSet config '.transport.path="/"+$ARGS.positional[0]' "$(urldecode "$(jsonSelect params '.path')" | $SED 's|^/||' )"
					fi
				;;
				ws)
					isEmpty "$(jsonSelect params '.host')" ||
						jsonSet config '.transport.headers.Host=$ARGS.positional[0]' "$(urldecode "$(jsonSelect params '.host')" )"
					if ! isEmpty "$(jsonSelect params '.path')"; then
						local transport_depath="$(urldecode "$(jsonSelect params '.path')" )"
						if echo "$transport_depath" | grep -qE "\?ed="; then
							jsonSet config \
								'. as $config |
								$ARGS.positional[0]|split("?ed=") as $data |
								$config |
								.transport.early_data_header_name="Sec-WebSocket-Protocol" |
								.transport.max_early_data=($data[1]|tonumber) |
								.transport.path="/"+$data[0]' \
								"${transport_depath#/}"
						else
							jsonSet config '.transport.path="/"+$ARGS.positional[0]' "${transport_depath#/}"
						fi
					fi
				;;
			esac
		;;
		vmess)
			# Shadowrocket format
			if echo "$uri" | grep -q "&"; then
				logs warn "parse_uri: Skipping unsupported VMess node '$uri'.\n"
				return 1
			fi

			# https://github.com/2dust/v2rayN/wiki/%E5%88%86%E4%BA%AB%E9%93%BE%E6%8E%A5%E6%A0%BC%E5%BC%8F%E8%AF%B4%E6%98%8E(ver-2)
			url="$(decodeBase64Str "$body")"
			[ -n "$url" ] || {
				logs warn "parse_uri: Skipping unsupported VMess node '$uri'.\n"
				return 1
			}
			[ "$(jsonSelect url '.v')" = "2" ] || {
				logs warn "parse_uri: Skipping unsupported VMess node '$uri'.\n"
				return 1
			}
			if [ "$(jsonSelect url '.net')" = "kcp" ]; then
				logs warn "parse_uri: Skipping unsupported VMess node '$uri'.\n"
				return 1
			elif [ "$(jsonSelect url '.net')" = "quic" ]; then
				if validation features 'with_quic'; then
					if [ -n "$(jsonSelect url '.type')" -a "$(jsonSelect url '.type')" != "none" ] || [ -n "$(jsonSelect url '.path')" ]; then
						logs warn "parse_uri: Skipping unsupported VMess node '$uri'.\n"
						return 1
					fi
				else
					logs warn "parse_uri: Skipping unsupported VMess node '$uri'.\n\tPlease rebuild sing-box with QUIC support!\n"
					return 1
				fi
			fi

			jsonSet config \
				'.type="vmess" |
				.tag=$ARGS.positional[0] |
				.server=$ARGS.positional[1] |
				.server_port=($ARGS.positional[2]|tonumber) |
				.uuid=$ARGS.positional[3]' \
				"$(isEmpty "$(jsonSelect url '.ps')" && calcStringMD5 "$uri" || jsonSelect url '.ps' )" \
				"$(jsonSelect url '.add')" \
				"$(jsonSelect url '.port')" \
				"$(jsonSelect url '.id')"
			# security
			isEmpty "$(jsonSelect url '.scy')" &&
				jsonSet config '.security="auto"' ||
				jsonSet config '.security=$ARGS.positional[0]' "$(jsonSelect url '.scy')"
			# alter_id
			isEmpty "$(jsonSelect url '.aid')" ||
				jsonSet config '.alter_id=($ARGS.positional[0]|tonumber)' "$(jsonSelect url '.aid')"
			# global_padding
			jsonSet config '.global_padding=true'
			# tls
			[ "$(jsonSelect url '.tls')" = "tls" ] &&
				jsonSet config '.tls.enabled=true'
			if ! isEmpty "$(jsonSelect url '.sni')"; then
				jsonSet config '.tls.server_name=$ARGS.positional[0]' "$(jsonSelect url '.sni')"
			elif ! isEmpty "$(jsonSelect url '.host')"; then
				jsonSet config '.tls.server_name=$ARGS.positional[0]' "$(jsonSelect url '.host')"
			fi
			isEmpty "$(jsonSelect url '.alpn')" ||
				jsonSet config '.tls.alpn=($ARGS.positional[0]|split(","))' "$(jsonSelect url '.alpn')"
			# transport
			local transport_type="$(jsonSelect url '.net')"
			if ! isEmpty "$transport_type" && [ "$transport_type" != "tcp" ]; then
				jsonSet config '.transport.type=$ARGS.positional[0]' "$transport_type"
			fi
			case "$transport_type" in
				grpc)
					isEmpty "$(jsonSelect url '.path')" ||
						jsonSet config '.transport.service_name=$ARGS.positional[0]' "$(jsonSelect url '.path')"
				;;
				tcp|h2)
					if [ "$transport_type" = "h2" -o "$(jsonSelect url '.type')" = "http" ]; then
						jsonSet config '.transport.type="http"'
						isEmpty "$(jsonSelect url '.host')" ||
							jsonSet config '.transport.host=($ARGS.positional[0]|split(","))' "$(jsonSelect url '.host')"
						isEmpty "$(jsonSelect url '.path')" ||
							jsonSet config '.transport.path="/"+$ARGS.positional[0]' "$(jsonSelect url '.path' | $SED 's|^/||')"
					fi
				;;
				ws)
					isEmpty "$(jsonSelect url '.host')" ||
						jsonSet config '.transport.headers.Host=$ARGS.positional[0]' "$(jsonSelect url '.host')"
					if ! isEmpty "$(jsonSelect url '.path')"; then
						local transport_depath="$(jsonSelect url '.path')"
						if echo "$transport_depath" | grep -qE "\?ed="; then
							jsonSet config \
								'. as $config |
								$ARGS.positional[0]|split("?ed=") as $data |
								$config |
								.transport.early_data_header_name="Sec-WebSocket-Protocol" |
								.transport.max_early_data=($data[1]|tonumber) |
								.transport.path="/"+$data[0]' \
								"${transport_depath#/}"
						else
							jsonSet config '.transport.path="/"+$ARGS.positional[0]' "${transport_depath#/}"
						fi
					fi
				;;
			esac
		;;
		*)
			logs warn "parse_uri: Skipping unsupported node '$uri'.\n"
			return 1
		;;
	esac

	if ! isEmpty "$config"; then
		isEmpty "$(jsonSelect config '.server')" ||
			jsonSet config '.server=$ARGS.positional[0]' "$(jsonSelect config '.server' | tr -d '[]')"
	fi

	eval "$1=\"\$config\""
}

# func <var> <subscription_url>
parse_provider() {
	echo "$1" | grep -qE "^(node|nodes|result|results|url|time|count)$" &&
		{ logs err "parse_provider: Variable name '$1' is conflict.\n"; return 1; }
	local node nodes result results='[]' url="$2"
	[ -n "$1" ] && eval "$1=''" || return 1

	nodes="$(decodeBase64Str "$(wfetch "$url" "$UA")" | tr -d '\r' | $SED 's|\s|%20|g')"
	[ -n "$nodes" ] || {
		logs warn "parse_provider: Unable to resolve resource from provider '$url'.\n"
		return 1
	}

	local time=$($DATE -u +%s%3N) count=0
	for node in $nodes; do
		[ -n "$node" ] && parse_uri result "$node"
		isEmpty "$result" && continue
		# filter
		filterCheck "$(jsonSelect result '.tag')" "$FILTER" && { logs note "parse_provider: Skipping node: $(jsonSelect result '.tag').\n"; continue; }

		jsonSetjson results ".[$count]=\$ARGS.positional[0]" "$result"
		let count++
	done
	time=$[ $($DATE -u +%s%3N) - $time ]
	logs yeah "Successfully fetched $count nodes of total $(echo "$nodes"|wc -l|tr -d " ") from '$url'.\n"
	logs yeah "Total time: $[ $time / 60000 ]m$[ $time / 1000 % 60 ]s$[ $time % 1000 ]ms.\n"

	if isEmpty "$results"; then
		logs err "parse_provider: Failed to update provider: no valid node found.\n"
		return 1
	fi

	eval "$1=\"\$results\""
}

# func <namestr> [filter]
filterCheck() {
	local name="$1" filter="$2" rcode
	[ -n "$filter" ] || return 1

	rcode="$(jsonSelect filter \
		'$ARGS.positional[0] as $name |
		last(
			label $out | .[] | (
				.action as $action |
				.regex as $regex |
				$name | test($regex;null) | if $action == "include" then not else . end |
				if . then true, break $out else false end
			)
		)' \
		"$name" \
	)"

	[ "$rcode" = "true" ] || return 1
}
