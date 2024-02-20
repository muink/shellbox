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
	echo "&$1" | sed -E 's|=&|\&|g;s|&([^=&]+)=([^&]+)|"\1":"\2",|g;s|&[^"]+||g;s|,$||;s|^(.*)$|{\1}|' # DONOT decode params value, sed cannot handle array or object
	#echo "$1" | jq -Rc 'splits("&|;") | split("=") as [$key, $val] | {($key): $val}' | jq -sc 'add // {}'
}

# func <obj>
urlencode_params() {
	isEmpty "$1" && return 0
	echo "$1" | jq '. | length as $count | keys_unsorted as $keys | map(.) as $vals | 0 | while(. < $count; .+1) | "\($keys[.])=\($vals[.])"' | jq -src 'join("&")'
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
			echo "$str" | sed 's|^\[\(.*\)\]$|\1|' | grep -qE "^(\
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
	[ -n "$1" ] || return 1
	local url="$1"
	local protocol userinfo username password host port path search hash

	# hash / URI fragment    /#(.+)$/
	hash="$(echo "$url" | sed -En 's|.*#(.+)$|\1|p')"
	url="${url%#*}"
	# protocol / URI scheme    /^([[:alpha:]][[:alpha:]\d\+\-\.]*):\/\//
	eval "$(echo "$url" | sed -En "s|^([[:alpha:]][[:alnum:]\.+-]*)://(.+)|protocol='\1';url='\2'|p")"
	[ -n "$protocol" ] || return 1
	# userinfo    /^([^@]+)@/
	# host    /^[\w\-\.]+/
	# port    /^:(\d+)/
	eval "$(echo "$url" | sed -En "s,^(([^@]+)@)?([[:alnum:]_\.-]+|\[[[:xdigit:]:\.]+\])(:([0-9]+))?(.*),userinfo='\2';host='\3';port='\5';url='\6',p")"
	host="$(echo "$host" | tr -d '[]')"
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
		eval "$(echo "$userinfo" | sed -En "s|^([^:]+)(:([^:]+))?.*|username='\1';password='\3'|p")"
	fi

	# path    /^(\/[^\?\#]*)/
	# search / URI query    /^\?([^#]+)/
	eval "$(echo "$url" | sed -En "s|^(/[^\?#]*)?(\?([^#]+))?.*|path='\1';search='\3'|p")"

	# pre-decode
	[ -n "$hash" ] && hash="$(urldecode "$hash")" || hash="$(calcStringMD5 "$url")"
	[ -n "$username" ] && username="\"$(urldecode "$username")\"" || username=null
	[ -n "$password" ] && password="\"$(urldecode "$password")\"" || password=null
	[ -n "$path" ] && path="\"$(urldecode "$path")\"" || path=null
	#search

	echo "$(cat <<-EOF
		{
			"protocol": "$protocol",
			"hash": "$hash",
			"host": "$host",
			"port": $port,
			"username": $username,
			"password": $password,
			"path": $path,
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
	userinfo="$(jsonSelect obj 'if .username then (.username|@uri) else "" end + if .password then ":" + (.password|@uri) else "" end')"
	hostport="$(jsonSelect obj 'if (.host | test(":")) then "[\(.host)]" else .host end + ":\(.port)"')"
	path="$(jsonSelect obj '.path')"
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
	echo "$1" | grep -qE "^(config|url|rcode|uri|type|body|ss_body|ss_lable)$" &&
		{ logs err "parse_uri: Variable name '$1' is conflict.\n"; return 1; }
	local config='{}' url rcode
	[ -n "$1" ] && eval "$1=''" || return 1
	local uri="$2" type="${2%%:*}" body="$(echo "$2" | sed -E 's|^([[:alpha:]][[:alnum:]\.+-]*)://||')"

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
				| if $url.username then .username=$url.username else . end
				| if $url.password then .password=$url.password else . end
				# tls
				| if $url.protocol == "https" then .tls.enabled=true else . end' \
				"$url"
		;;
		hysteria)
			# https://v1.hysteria.network/docs/uri-scheme/
			url="$(parseURL "$uri")"
			[ -z "$url" ] && { logs warn "parse_uri: node '$uri' is not a valid format.\n"; return 1; }

			if validation features 'with_quic'; then
				if [ "$(jsonSelect url '.searchParams.protocol | length > 0 and . != "udp"')" = "true" ]; then
					logs warn "parse_uri: Skipping unsupported hysteria node '$uri'.\n"
					return 1
				fi
			else
				logs warn "parse_uri: Skipping unsupported hysteria node '$uri'.\n\tPlease rebuild sing-box with QUIC support!\n"
				return 1
			fi

			jsonSetjson config \
				'$ARGS.positional[0] as $url
				| $url.searchParams as $params
				| .type="hysteria"
				| .tag=$url.hash
				| .server=$url.host
				| .server_port=$url.port
				| .up_mbps=($params.upmbps|tonumber)
				| .down_mbps=($params.downmbps|tonumber)
				# obfs
				| if $params.obfsParam then .obfs=($params.obfsParam|urid) else . end
				# auth_str
				| if $params.auth then .auth_str=($params.auth|urid) else . end
				# tls
				| .tls.enabled=true
				| if $params.peer then .tls.server_name=($params.peer|urid) else . end
				| if ($params.insecure | . == "1" or . == "true") then .tls.insecure=true else . end
				| if $params.alpn then .tls.alpn=$params.alpn else . end' \
				"$url"
		;;
		hysteria2|hy2)
			# https://v2.hysteria.network/docs/developers/URI-Scheme/
			url="$(parseURL "$uri")"
			[ -z "$url" ] && { logs warn "parse_uri: node '$uri' is not a valid format.\n"; return 1; }

			if ! validation features 'with_quic'; then
				logs warn "parse_uri: Skipping unsupported hysteria2 node '$uri'.\n\tPlease rebuild sing-box with QUIC support!\n"
				return 1
			fi

			jsonSetjson config \
				'$ARGS.positional[0] as $url
				| $url.searchParams as $params
				| .type="hysteria2"
				| .tag=$url.hash
				| .server=$url.host
				| .server_port=$url.port
				| .tls.enabled=true
				# password
				| if $url.username then .password=$url.username else . end
				| if $url.password then .password=.password + ":" + $url.password else . end
				| if ($params|length) > 0 then
					# obfs
					if $params.obfs then .obfs.type=$params.obfs else . end
					| if $params["obfs-password"] then .obfs.password=($params["obfs-password"]|urid) else . end
					# tls
					| if $params.sni then .tls.server_name=($params.sni|urid) else . end
					| if $params.insecure == "1" then .tls.insecure=true else . end
				else . end' \
				"$url"
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
				| if $url.username then .username=$url.username else . end
				| if $url.password then .password=$url.password else . end' \
				"$url"
		;;
		ss)
			# Shadowrocket format
			local ss_body ss_lable
			eval "$(echo "$body" | sed -En "s|^([^#]+)(#.*)?|ss_body='\1';ss_lable='\2'|p")"
			ss_body="$(decodeBase64Str "$ss_body")"
			[ -n "$ss_body" ] && uri="$type://$ss_body$ss_lable"

			# https://shadowsocks.org/doc/sip002.html
			url="$(parseURL "$uri")"
			[ -z "$url" ] && { logs warn "parse_uri: node '$uri' is not a valid format.\n"; return 1; }

			jsonSetjson config \
				'$ARGS.positional[0] as $url
				| $url.searchParams as $params
				| .type="shadowsocks"
				| .tag=$url.hash
				| .server=$url.host
				| .server_port=$url.port
				# method password
				| if $url.password then
					.method=$url.username
					| .password=$url.password
				else
					($url.username | @base64d | split(":")) as $userinfo
					| .method=$userinfo[0]
					| .password=$userinfo[1]
				end
				# plugin plugin_opts
				| if $params.plugin then
					($params.plugin | urid | split(";")) as $pluginfo
					| .plugin=($pluginfo[0] | if . == "simple-obfs" then "obfs-local" else . end)
					| .plugin_opts=($pluginfo[1:] | join(";"))
				else . end' \
				"$url"
		;;
		trojan)
			# https://p4gefau1t.github.io/trojan-go/developer/url/
			url="$(parseURL "$uri")"
			[ -z "$url" ] && { logs warn "parse_uri: node '$uri' is not a valid format.\n"; return 1; }

			jsonSetjson config \
				'$ARGS.positional[0] as $url
				| $url.searchParams as $params
				| .type="trojan"
				| .tag=$url.hash
				| .server=$url.host
				| .server_port=$url.port
				| .password=$url.username
				| .tls.enabled=true
				| if ($params|length) > 0 then
					# tls
					if $params.sni then .tls.server_name=($params.sni|urid) else . end
					# transport
					| if $params.type and $params.type != "tcp" then
						($params.type|urid) as $type
						| .transport.type=$type
						| if $type == "grpc" then
							.transport.service_name=($params.serviceName|urid)
						elif $type == "ws" then
							if $params.host then .transport.headers.Host=($params.host|urid) else . end
							| if $params.path then
								($params.path|urid) as $path
								| if ($path | test("\\?ed=")) then
									($path | split("?ed=")) as $data
									| .transport.early_data_header_name="Sec-WebSocket-Protocol"
									| .transport.max_early_data=($data[1]|tonumber)
									| .transport.path=$data[0]
								else
									.transport.path=$path
								end
							else . end
						else . end
					else . end
				else . end' \
				"$url"
		;;
		tuic)
			# https://github.com/daeuniverse/dae/discussions/182
			url="$(parseURL "$uri")"
			[ -z "$url" ] && { logs warn "parse_uri: node '$uri' is not a valid format.\n"; return 1; }

			if ! validation features 'with_quic'; then
				logs warn "parse_uri: Skipping unsupported TUIC node '$uri'.\n\tPlease rebuild sing-box with QUIC support!\n"
				return 1
			fi

			jsonSetjson config \
				'$ARGS.positional[0] as $url
				| $url.searchParams as $params
				| .type="tuic"
				| .tag=$url.hash
				| .server=$url.host
				| .server_port=$url.port
				| .uuid=$url.username
				| .tls.enabled=true
				# password
				| if $url.password then .password=$url.password else . end
				| if ($params|length) > 0 then
					# congestion_control
					if $params.congestion_control then .congestion_control=$params.congestion_control else . end
					# udp_relay_mode
					| if $params.udp_relay_mode then .udp_relay_mode=$params.udp_relay_mode else . end
					# tls
					| if $params.sni then .tls.server_name=($params.sni|urid) else . end
					| if $params.alpn then .tls.alpn=($params.alpn | urid | split(",")) else . end
				else . end' \
				"$url"
		;;
		vless)
			# https://github.com/XTLS/Xray-core/discussions/716
			url="$(parseURL "$uri")"
			[ -z "$url" ] && { logs warn "parse_uri: node '$uri' is not a valid format.\n"; return 1; }

			case "$(jsonSelect url '.searchParams.type')" in
				kcp)
					logs warn "parse_uri: Skipping unsupported VLESS node '$uri'.\n"
					return 1
				;;
				quic)
					if validation features 'with_quic'; then
						if [ "$(jsonSelect url '.searchParams.quicSecurity | length > 0 and . != "none"')" = "true" ]; then
							logs warn "parse_uri: Skipping unsupported VLESS node '$uri'.\n"
							return 1
						fi
					else
						logs warn "parse_uri: Skipping unsupported VLESS node '$uri'.\n\tPlease rebuild sing-box with QUIC support!\n"
						return 1
					fi
				;;
			esac

			jsonSetjson config \
				'$ARGS.positional[0] as $url
				| $ARGS.positional[1] as $utls
				| $url.searchParams as $params
				| .type="vless"
				| .tag=$url.hash
				| .server=$url.host
				| .server_port=$url.port
				| .uuid=$url.username
				| if ($params|length) > 0 then
					$params.security as $security
					# security
					| if ($security | . == "tls" or . == "xtls" or . == "reality") then
						.tls.enabled=true
						# flow
						| if $params.flow then .flow=$params.flow else . end
					else . end
					# tls
					| if $params.sni then .tls.server_name=($params.sni|urid) else . end
					| if $params.alpn then .tls.alpn=($params.alpn | urid | split(",")) else . end
					| if $params.fp and $utls then
						.tls.utls.enabled=true
						| .tls.utls.fingerprint=$params.fp
					else . end
					# reality
					| if $security == "reality" then
						.reality.enabled=true
						| if $params.pbk then .reality.public_key=($params.pbk|urid) else . end
						| if $params.sid then .reality.short_id=$params.sid else . end
					else . end
					# transport
					| if $params.type and $params.type != "tcp" then
						($params.type|urid) as $type
						| .transport.type=$type
						| if $type == "grpc" then
							.transport.service_name=($params.serviceName|urid)
						elif ($type | test("^(tcp|http)$")) then
							if $type == "http" or $params.headerType == "http" then
								if $params.host then .transport.host=($params.host | urid | split(",")) else . end
								| if $params.path then .transport.path=($params.path|urid) else . end
							else . end
						elif $type == "ws" then
							if $params.host then .transport.headers.Host=($params.host|urid) else . end
							| if $params.path then
								($params.path|urid) as $path
								| if ($path | test("\\?ed=")) then
									($path | split("?ed=")) as $data
									| .transport.early_data_header_name="Sec-WebSocket-Protocol"
									| .transport.max_early_data=($data[1]|tonumber)
									| .transport.path=$data[0]
								else
									.transport.path=$path
								end
							else . end
						else . end
					else . end
				else . end' \
				"$url" "$(validation features 'with_utls' && echo true || echo false)"
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
			rcode="$(jsonSelect url \
				'$ARGS.positional[0] as $uri
				| $ARGS.positional[1] as $quic
				| if "\(.v)" == "2" then
					if .net == "kcp" then
						"Skipping unsupported VMess node \\x27\($uri)\\x27."
					elif .net == "quic" then
						if $quic then
							if ((.type|length) > 0 and .type != "none") or (.path|length) > 0 then
								"Skipping unsupported VMess node \\x27\($uri)\\x27."
							else 0 end
						else "Skipping unsupported VMess node \\x27\($uri)\\x27.\\n\\tPlease rebuild sing-box with QUIC support!" end
					else 0 end
				else "Skipping unsupported VMess node \\x27\($uri)\\x27." end' \
				"$uri" "$(validation features 'with_quic' && echo true || echo false)" \
			)"
			[ "$rcode" = "0" ] || { logs warn "parse_uri: $rcode\n"; return 1; }

			jsonSetjson config \
				'$ARGS.positional[0] as $url
				| .type="vmess"
				| .tag=$url.ps
				| .server=$url.add
				| .server_port=($url.port|tonumber)
				| .uuid=$url.id
				# security
				| if ($url.scy|length) > 0 then .security=$url.scy else .security="auto" end
				# alter_id
				| if $url.aid then .alter_id=($url.aid|tonumber) else . end
				# global_padding
				| .global_padding=true
				# tls
				| if $url.tls == "tls" then .tls.enabled=true else . end
				| if ($url.sni|length) > 0 then
					.tls.server_name=$url.sni
				else
					if ($url.host|length) > 0 then .tls.server_name=$url.host else . end
				end
				| if ($url.alpn|length) > 0 then .tls.alpn=($url.alpn | split(",")) else . end
				# transport
				| $url.net as $type
				| if ($type|length) > 0 and $type != "tcp" then .transport.type=$type else . end
				| if $type == "grpc" then
					.transport.service_name=$url.path
				elif ($type | test("^(tcp|h2)$")) then
					if $type == "h2" or $url.type == "http" then
						.transport.type="http"
						| if ($url.host|length) > 0 then .transport.host=($url.host | split(",")) else . end
						| if ($url.path|length) > 0 then .transport.path=$url.path else . end
					else . end
				elif $type == "ws" then
					if ($url.host|length) > 0 then .transport.headers.Host=$url.host else . end
					| $url.path as $path
					| if ($path|length) > 0 then
						if ($path | test("\\?ed=")) then
							($path | split("?ed=")) as $data
							| .transport.early_data_header_name="Sec-WebSocket-Protocol"
							| .transport.max_early_data=($data[1]|tonumber)
							| .transport.path=$data[0]
						else
							.transport.path=$path
						end
					else . end
				else . end' \
				"$url"
		;;
		*)
			logs warn "parse_uri: Skipping unsupported node '$uri'.\n"
			return 1
		;;
	esac

	eval "$1=\"\$config\""
}

# func <var> <subscription_url>
parse_provider() {
	echo "$1" | grep -qE "^(i|node|nodes|result|results|total|count|name|url|time)$" &&
		{ logs err "parse_provider: Variable name '$1' is conflict.\n"; return 1; }
	local i node nodes result results='[]' total count name url="$2"
	[ -n "$1" ] && eval "$1=''" || return 1

	nodes="$(decodeBase64Str "$(wfetch "$url" "$UA")" | tr -d '\r' | sed 's|\s|%20|g')"
	[ -n "$nodes" ] || {
		logs warn "parse_provider: Unable to resolve resource from provider '$url'.\n"
		return 1
	}
	total=$(echo "$nodes" | wc -l) count=0

	local time=$(date -u +%s%3N)
	case "$OS" in
		windows|darwin)
			for node in $nodes; do
				[ -n "$node" ] && parse_uri result "$node"
				isEmpty "$result" && continue
				# filter
				name="$(jsonSelect result '.tag')"
				filterCheck "$name" "$FILTER" && { logs note "parse_provider: Skipping node: $name.\n"; continue; }

				jsonSetjson results ".[$count]=\$ARGS.positional[0]" "$result"
				progress "$total" "$count"
				let count++
			done
		;;
		*)
			tmpfd 8 # Results
			tmpfd 6; for i in $(seq 1 $NPROC); do echo 0 >&6; done # Generate $NPROC tokens
			for node in $(echo "$nodes" | awk '{print NR ">" $s}'); do
				read -u6 count # Take token
				{
					parse_uri result "${node#*>}"
					isEmpty "$result" && { echo $count >&6; exit 0; }
					# filter
					name="$(jsonSelect result '.tag')"
					filterCheck "$name" "$FILTER" && { logs note "parse_provider: Skipping node: $name.\n"; echo $count >&6; exit 0; }

					echo "${node%%>*} $result" >&8
					progress "$[ $total /$NPROC ]" "$count"
					let count++
					echo $count >&6 # Release token
				} &
			done; wait; count=0
			count=$[ $( head -n$NPROC /proc/$$/fd/6 | tr '\n' '+') 0 ]
			if [ $count -ne 0 ]; then
				results="$( head -n$count /proc/$$/fd/8 | sort -n | sed -E 's|^[0-9]+\s*||' | tr '\n' ',' )"
				results="[${results:0: -1}]"
			fi
			unfd 8; unfd 6
		;;
	esac
	time=$[ $(date -u +%s%3N) - $time ]
	logs yeah "Successfully fetched $count nodes of total $(echo "$nodes"|wc -l|tr -d " ") from '$url'.\n"
	logs yeah "Total time: $[ $time / 60000 ]m$[ $time / 1000 % 60 ].$[ $time % 1000 ]s.\n"

	eval "$1=\"\$results\""
}

# func <name> [filter]
filterCheck() {
	local name="$1" filter="$2" rcode
	[ -n "$filter" ] || return 1

	rcode="$(jsonSelect filter \
		'$ARGS.positional[0] as $name
		| def exclude:
			def loop($i):
				if $i >= length then .[0].action == "include" else
					.[$i].regex as $regex
					| if ($name | test($regex;null)) then .[$i].action == "exclude"
					else loop($i+1) end
				end;
			loop(0);
		exclude' \
		"$name" \
	)"

	[ "$rcode" = "true" ] || return 1
}
