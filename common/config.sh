#!/bin/bash
# Copyright (C) 2024 Anya Lin
#
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.
#

export JQFUNC_filter='def filter:
	def loop($q):
		if $q >= length then empty else
			if (.[$q] | type == "object" and length > 0) then
				# Field check
				if (.[$q].action | type != "string" or (test("^(include|exclude)$") | not)) then
					"Invalid field of the key [\"action\"] for filter [\($q)] for provider [$i]."
				elif (.[$q].regex | type != "string") then
					"Invalid field of the key [\"regex\"] for filter [\($q)] for provider [$i]."
				else empty, loop($q+1) end
			else "Filter [\($q)] of the provider [$i] is invalid." end
		end;
	if type == "array" then loop(0)
	else 1 end;'

# func <providers>
verifyProviders() {
	local providers="$1" rcode

	local JQFUNC_subgroup='def subgroup:
		def loop($q):
			if $q >= length then empty else
				if (.[$q] | type == "string" and length > 0) then empty, loop($q+1)
				else "Subgroup [\($q)] of the provider [$i] is invalid." end
			end;
		if type == "string" then empty
		elif type == "array" then loop(0)
		else 1 end;'

	local JQFUNC_provider="$JQFUNC_filter $JQFUNC_subgroup"'def provider:
		def verify($k):
			# Required
			if $k == "url" then
				if type == "string" and length > 0 then empty else 1 end
			elif $k == "tag" then
				if type == "string" and test("^[[:word:]]+$") then empty else 1 end
			# Optional
			elif $k == "prefix" then
				if . == null or type == "string" then empty else 1 end
			elif $k == "ua" then
				if . == null or type == "string" then empty else 1 end
			elif $k == "subgroup" then
				if . == null then empty else subgroup end
			elif $k == "filter" then
				if . == null then empty else filter end
			else empty end
			| if . == 1 then "Key [\"\($k)\"] of the provider [$i] is invalid." else gsub("\\$k"; "\($k)") end;
		if type == "object" and length > 0 then
			(.url | verify("url"))
			// (.tag | verify("tag"))
			// (.subgroup | verify("subgroup"))
			// (.prefix | verify("prefix"))
			// (.ua | verify("ua"))
			// (.filter | verify("filter"))
		else "Provider [$i] is invalid." end;'

	local JQFUNC_providers="$JQFUNC_provider"'def providers:
		def loop($i):
			if $i >= length then empty else (.[$i] | provider | gsub("\\$i"; "\($i)")) // loop($i+1) end;
		if type == "array" and length > 0 then loop(0)
		else "No providers available." end;'

	if [ -n "$providers" ]; then
		rcode="$(jsonSelect providers "$JQFUNC_providers"'providers' )"
	else
		rcode="No providers available."
	fi

	[ -z "$rcode" ] || { logs err "verifyProviders: $rcode\n"; return 1; }
	return 0
}

updateProvider() {
	[ -x "$(command -v "$SINGBOX")" ] || { logs err "sing-box is not installed.\n"; return 1; }
	local setting="$(cat "$MAINSET")"
	local providers="$(jsonSelect setting '.providers')"
	verifyProviders "$providers" || return 1

	local provider total="$(jsonSelect providers 'length')" count=0
	local node_result UA FILTER

	local time=$(date -u +%s%3N) i k
	for i in $(seq 0 $[ $total -1 ]); do
		provider="$(jsonSelect providers ".[$i]")"
		# Keys: url tag #subgroup #prefix ua filter
		for k in url tag ua filter; do
			eval "local $k=\"\$(jsonSelect provider '.$k')\""
		done
		# Updating
		UA="$ua" FILTER="$filter"
		parse_provider node_result "$url" || continue

		echo "$node_result" > "$SUBSDIR/$tag.json"
		let count++
	done
	time=$[ $(date -u +%s%3N) - $time ]
	logs yeah "Successfully updated $count providers of total $total.\n"
	logs yeah "Total time: $[ $time / 60000 ]m$[ $time / 1000 % 60 ].$[ $time % 1000 ]s.\n"
}

# func <configs>
verifyConfigs() {
	local configs="$1" rcode

	local JQFUNC_providers='def providers:
		def loop($q):
			if $q >= length then empty else
				if (.[$q] | type == "string" and test("^[[:word:]]+$")) then empty, loop($q+1)
				else "Provider [\($q)] of the config [$i] is invalid." end
			end;
		if type == "array" then loop(0)
		else 1 end;'

	local JQFUNC_templates='def templates:
		def loop($q):
			if $q >= length then empty else
				if (.[$q] | type == "string" and test("^[[:word:]\\.]+$")) then empty, loop($q+1)
				else "Template [\($q)] of the config [$i] is invalid." end
			end;
		if type == "array" and length > 0 then loop(0)
		else 1 end;'

	local JQFUNC_config="$JQFUNC_providers $JQFUNC_templates"'def config:
		def verify($k):
			# Required
			if $k == "output" then
				if type == "string" and test("^[[:word:]]+$") then empty else 1 end
			elif $k == "enabled" then
				if type == "boolean" then empty else 1 end
			elif $k == "providers" then
				providers
			elif $k == "templates" then
				templates
			else empty end
			| if . == 1 then "Key [\"\($k)\"] of the config [$i] is invalid." else gsub("\\$k"; "\($k)") end;
		if type == "object" and length > 0 then
			(.output | verify("output"))
			// (.enabled | verify("enabled"))
			// (.providers | verify("providers"))
			// (.templates | verify("templates"))
		else "Config [$i] is invalid." end;'

	local JQFUNC_configs="$JQFUNC_config"'def configs:
		def loop($i):
			if $i >= length then empty else (.[$i] | config | gsub("\\$i"; "\($i)")) // loop($i+1) end;
		if type == "array" and length > 0 then loop(0)
		else "No configs available." end;'

	if [ -n "$configs" ]; then
		rcode="$(jsonSelect configs "$JQFUNC_configs"'configs' )"
	else
		rcode="No configs available."
	fi

	[ -z "$rcode" ] || { logs err "verifyConfigs: $rcode\n"; return 1; }
	return 0
}

buildConfig() {
	[ -x "$(command -v "$SINGBOX")" ] || { logs err "sing-box is not installed.\n"; return 1; }
	local setting="$(cat "$MAINSET")"
	local providers="$(jsonSelect setting '.providers')"
	local configs="$(jsonSelect setting '.configs')"
	verifyProviders "$providers" || return 1
	verifyConfigs "$configs" || return 1

	local config total="$(jsonSelect configs 'length')" count=0
	local cfg_result outbounds PROVIDERS="$(jsonSelect providers 'del(.[].url, .[].ua, .[].filter)')"

	local time=$(date -u +%s%3N) i k
	for i in $(seq 0 $[ $total -1 ]); do
		config="$(jsonSelect configs ".[$i]")"
		# Keys: output enabled providers templates
		for k in output enabled providers templates; do
			eval "local $k=\"\$(jsonSelect config '.$k')\""
		done
		# Updating
		[ "$enabled" = "true" ] || continue

		pushd "$TEMPDIR" >/dev/null
		eval "jsonMergeFiles cfg_result $(jsonSelect templates '@sh')" || { logs err "build_config: Templates merge failed.\n"; popd; continue; }
		popd >/dev/null
		outbounds="$(jsonSelect cfg_result '.outbounds')"

		build_outbound outbounds "$outbounds" "$providers" || continue
		cfg_result="[$cfg_result,${outbounds:-[]}]"
		jsonSet cfg_result '.[0].outbounds=.[1] | .[0]'

		echo "$cfg_result" | jq > "$CONFDIR/$output.json"
		let count++
	done
	time=$[ $(date -u +%s%3N) - $time ]
	logs yeah "Successfully built $count configs of total $total.\n"
	logs yeah "Total time: $[ $time / 60000 ]m$[ $time / 1000 % 60 ].$[ $time % 1000 ]s.\n"
}

# func <settings>
verifySettings() {
	local settings="$1" rcode

	local JQFUNC_settings='def settings:
		def mixed_in:
			if type == "object" then
				(.enabled | if . == null or type == "boolean" then empty else "enabled" end)
				// (.port | if type == "number" then empty else "port" end)
				// (.set_system_proxy | if . == null or type == "boolean" then empty else "set_system_proxy" end)
			else 1 end;
		def tun_in:
			if type == "object" then
				(.enabled | if . == null or type == "boolean" then empty else "enabled" end)
				// (.endpoint_independent_nat | if . == null or type == "boolean" then empty else "endpoint_independent_nat" end)
				// (.udp_timeout | if . == null or type == "string" then empty else "udp_timeout" end)
				// (.stack | if . == null or type == "string" then empty else "stack" end)
			else 1 end;
		def clash_api:
			if type == "object" then
				(.external_controller | if . == null or type == "string" then empty else "external_controller" end)
				// (.secret | if . == null or type == "string" then empty else "secret" end)
			else 1 end;
		def verify($k):
			# Optional
			if $k == "default_interface" then
				if . == null or type == "string" then empty else 1 end
			elif $k == "sniff_override_destination" then
				if . == null or type == "boolean" then empty else 1 end
			elif $k == "log_level" then
				if . == null or type == "string" then empty else 1 end
			elif $k == "dns_port" then
				if . == null or type == "number" then empty else 1 end
			elif $k == "mixed_in" then
				if . == null then empty else mixed_in end
			elif $k == "tun_in" then
				if . == null then empty else tun_in end
			elif $k == "clash_api" then
				if . == null then empty else clash_api end
			# Required
			elif $k == "mixin" then
				if type == "boolean" then empty else 1 end
			elif $k == "service_mode" then
				if type == "boolean" then empty else 1 end
			elif $k == "start_at_boot" then
				if type == "boolean" then empty else 1 end
			elif $k == "shortcut" then
				if type == "boolean" then empty else 1 end
			elif $k == "config" then
				if type == "string" and test("^[[:word:]]+$") then empty else 1 end
			else empty end
			| if . == 1 then "Key [\"\($k)\"] of the settings is invalid." else
				"Key [\"\($k).\(.)\"] of the settings is invalid."
			end;
		if type == "object" and length > 0 then
			(.default_interface | verify("default_interface"))
			// (.sniff_override_destination | verify("sniff_override_destination"))
			// (.log_level | verify("log_level"))
			// (.dns_port | verify("dns_port"))
			// (.mixed_in | verify("mixed_in"))
			// (.tun_in | verify("tun_in"))
			// (.clash_api | verify("clash_api"))
			// (.mixin | verify("mixin"))
			// (.service_mode | verify("service_mode"))
			// (.start_at_boot | verify("start_at_boot"))
			// (.shortcut | verify("shortcut"))
			// (.config | verify("config"))
		else "No settings exist." end;'

	if [ -n "$settings" ]; then
		rcode="$(jsonSelect settings "$JQFUNC_settings"'settings' )"
	else
		rcode="No settings exist."
	fi

	[ -z "$rcode" ] || { logs err "verifySettings: $rcode\n"; return 1; }
	return 0
}

setSB() {
	[ -x "$(command -v "$SINGBOX")" ] || { logs err "sing-box is not installed.\n"; return 1; }
	local setting="$(cat "$MAINSET")"
	local settings="$(jsonSelect setting '.settings')"
	verifySettings "$settings" || return 1

	_exportVar() {
		jsonSelectjson "$1" \
			'def export($keys; $prefix):
				def loop($i):
					if $i >= ($keys | length) then empty else
						"local \($prefix)\($keys[$i])=\u0027\(.[$keys[$i]])\u0027", loop($i+1)
					end;
				[loop(0)] | join(";");
			export($ARGS.positional[0]; $ARGS.positional[1])' \
			"$2" "\"$3\""
	}

	# settings
	local sets='[
		"default_interface",
		"sniff_override_destination",
		"log_level",
		"dns_port",
		"mixed_in",
		"tun_in",
		"clash_api",
		"mixin",
		"service_mode",
		"start_at_boot",
		"shortcut",
		"config"
	]'
	sets="$(_exportVar settings "$sets" )"
	eval "$sets"
	# mixed_in
	sets='["enabled","port","set_system_proxy"]'
	sets="$(_exportVar mixed_in "$sets" mixed_in_ )"
	eval "$sets"
	# tun_in
	sets='["enabled","endpoint_independent_nat","udp_timeout","stack"]'
	sets="$(_exportVar tun_in "$sets" tun_in_ )"
	eval "$sets"
	# clash_api
	sets='["external_controller","secret"]'
	sets="$(_exportVar clash_api "$sets" clash_api_ )"
	eval "$sets"

	# runtimeConfig Post-processing
	if [ "$mixin" = "true" ]; then
		local config="$(cat "$CONFDIR/$config.json")"

		jsonSet config \
			'.log.output=$ARGS.positional[0]
			| .experimental.cache_file.path="cache.db"
			| .experimental.clash_api.external_ui=$ARGS.positional[1]' \
			"${LOGSDIR//$WORKDIR\//}/$(date +"%F-%H%M").log" "${DASHDIR//$WORKDIR\//}"
		# log_level
		isEmpty "$log_level" ||
			jsonSet config '.log.level=$ARGS.positional[0]' "$log_level"

		# inbounds
		local inbounds="$(jsonSelect config '.inbounds' 2>/dev/null)"
		[ -n "$inbounds" ] || inbounds='[]'
		# Allow all LAN, IPv4 and IPv6
		local JQFUNC_listenall='def listenall:
			def loop($i):
				if $i >= length then . else
					if (.[$i] | type == "object" and length > 0) then
						if .[$i].listen and (.[$i].listen | test("^(127(\\.[0-9]+){3}|::1)$")) then .[$i].listen="::" else . end
					else . end
					| loop($i+1)
				end;
			if type == "array" then loop(0)
			else . end;'
		local listenaddr='::'
		jsonSet inbounds "$JQFUNC_listenall"'listenall'
		# dns_port
		isEmpty "$dns_port" || {
			# inbounds
			jsonSet inbounds \
				"push({
					\"type\": \"direct\",
					\"tag\": \"shellbox-dns-in\",
					\"listen\": \"$listenaddr\",
					\"listen_port\": $dns_port
				})"
			# outbounds and route.rules
			local dns_out="$(jsonSelect config '.outbounds[] | select(.type == "dns") | .tag')"
			if [ -z "$dns_out" ]; then
				jsonSet config \
					'(.outbounds // []) as $outbounds
					| .outbounds=($outbounds | insert(0; {"type":"dns","tag":$ARGS.positional[0]}) )
					| (.route.rules // []) as $routerules
					| .route.rules=($routerules | insert(0; {"inbound":"shellbox-dns-in","outbound":$ARGS.positional[0]}) )' \
					"dns-out"
			else
				jsonSet config \
					'(.route.rules // []) as $routerules
					| .route.rules=($routerules | insert(0; {"inbound":"shellbox-dns-in","outbound":$ARGS.positional[0]}) )' \
					"$dns_out"
			fi
		}
		# mixed_in_enabled
		# mixed_in_port
		# mixed_in_set_system_proxy
		# sniff_override_destination
		[ "$mixed_in_enabled" = "true" ] &&
			jsonSet inbounds \
				"push({
					\"type\": \"mixed\",
					\"tag\": \"shellbox-mixed-in\",
					\"listen\": \"$listenaddr\",
					\"listen_port\": $mixed_in_port,
					\"sniff\": true
					$(isEmpty "$sniff_override_destination" || echo ,\"sniff_override_destination\": $sniff_override_destination)
					$(isEmpty "$mixed_in_set_system_proxy" || echo ,\"set_system_proxy\": $mixed_in_set_system_proxy)
				})"
		# tun_in_enabled
		# tun_in_endpoint_independent_nat
		# tun_in_udp_timeout
		# tun_in_stack
		# sniff_override_destination
		isEmpty "$tun_in_enabled" ||
			jsonSet inbounds '[.[] | select(.type == "tun" | not) ]'
		if [ "$tun_in_enabled" = "true" ]; then
			jsonSet inbounds \
				"push({
					\"type\": \"tun\",
					\"tag\": \"shellbox-tun-in\",
					\"interface_name\": \"\",
					\"inet4_address\": \"172.19.0.1/30\",
					\"inet6_address\": \"fdfe:dcba:9876::1/126\",
					\"mtu\": 9000,
					\"gso\": $([ "$OS" = "linux" ] && echo true || echo false),
					\"auto_route\": true,
					\"strict_route\": false
					$(isEmpty "$tun_in_endpoint_independent_nat" || echo ,\"endpoint_independent_nat\": $tun_in_endpoint_independent_nat)
					$(isEmpty "$tun_in_udp_timeout" || echo ,\"udp_timeout\": \"$tun_in_udp_timeout\")
					,\"stack\": \"$tun_in_stack\"
					,\"sniff\": true
					$(isEmpty "$sniff_override_destination" || echo ,\"sniff_override_destination\": $sniff_override_destination)
				})"
		fi
		config="[$config,$inbounds]"
		jsonSet config '.[0].inbounds=.[1] | .[0]'

		# clash_api_external_controller
		isEmpty "$clash_api_external_controller" ||
			jsonSet config '.experimental.clash_api.external_controller=$ARGS.positional[0]' "$clash_api_external_controller"
		# clash_api_secret
		case "$clash_api_secret" in
			"") jsonSet config '.experimental.clash_api.secret=$ARGS.positional[0]' "$(randomUUID)";;
			null) ;;
			*) jsonSet config '.experimental.clash_api.secret=$ARGS.positional[0]' "$clash_api_secret";;
		esac

		# default_interface
		case "$default_interface" in
			"") jsonSet config '.route.default_interface=$ARGS.positional[0]' "$(getDefaultIfname)";;
			null) ;;
			*) jsonSet config '.route.default_interface=$ARGS.positional[0]' "$default_interface";;
		esac

		echo "$config" | jq > "$RUNICFG"
	else
		cp -f "$CONFDIR/$config.json" "$RUNICFG"
	fi
	$SINGBOX check -D "$WORKDIR" -c "$RUNICFG"
	[ $? = 0 ] || { logs err "setSB: runtime config check is failed.\n"; return 1; }

	return 0

	# platform
	case "$OS" in
		windows)
			# shortcut
			if [ "$shortcut" = "true" ]; then
				windows_mkrun "shellbox.bat"
				windows_mkdash "."
			fi

			# start_at_boot
			if [ "$start_at_boot" = "true" ]; then
				# service_mode
				if [ "$service_mode" = "true" ]; then
					windows_task install
					windows_startup uninstall
				else
					windows_startup install
					windows_task uninstall
				fi
			else
				windows_task uninstall
				windows_startup uninstall
			fi
		;;
		darwin)
			# shortcut
			if [ "$shortcut" = "true" ]; then
				darwin_mkrun "shellbox.command"
				windows_mkdash "."
			fi

			# start_at_boot
			if [ "$start_at_boot" = "true" ]; then
				# service_mode
				if [ "$service_mode" = "true" ]; then
					darwin_daemon install
					darwin_startup uninstall "shellbox.command"
				else
					darwin_startup install "shellbox.command"
					darwin_daemon uninstall
				fi
			else
				darwin_daemon uninstall
				darwin_startup uninstall "shellbox.command"
			fi
		;;
		linux)
			# shortcut
			if [ "$shortcut" = "true" ]; then
				linux_mkrun "shellbox.desktop"
				linux_mkdash "."
			fi

			# start_at_boot
			if [ "$start_at_boot" = "true" ]; then
				# service_mode
			else
			fi
		;;
	esac

}
