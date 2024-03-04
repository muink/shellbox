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

		echo -n "$node_result" > "$SUBSDIR/$tag.json"
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
		jsonSetjson cfg_result '.outbounds=$ARGS.positional[0]' "${outbounds:-[]}"

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
		def clash_api:
			if type == "object" then
				(.controller_port | if . == null or type == "number" then empty else 1 end)
				// (.secret | if . == null or type == "string" then empty else 1 end)
			else 1 end;
		def verify($k):
			# Required
			if $k == "config" then
				if type == "string" and test("^[[:word:]]+$") then empty else 1 end
			elif $k == "start_at_boot" then
				if type == "boolean" then empty else 1 end
			elif $k == "set_system_proxy" then
				if type == "boolean" then empty else 1 end
			elif $k == "service_mode" then
				if type == "boolean" then empty else 1 end
			elif $k == "mixin" then
				if type == "boolean" then empty else 1 end
			# Optional
			elif $k == "allow_lan" then
				if . == null or type == "boolean" then empty else 1 end
			elif $k == "clash_api" then
				if . == null then empty else clash_api end
			elif $k == "log_level" then
				if . == null or type == "string" then empty else 1 end
			elif $k == "tun_mode" then
				if . == null or type == "boolean" then empty else 1 end
			elif $k == "mixed_port" then
				if . == null or type == "number" then empty else 1 end
			elif $k == "dns_port" then
				if . == null or type == "number" then empty else 1 end
			elif $k == "default_interface" then
				if . == null or type == "string" then empty else 1 end
			else empty end
			| if . == 1 then "Key [\"\($k)\"] of the settings is invalid." else . end;
		if type == "object" and length > 0 then
			(.default_interface | verify("default_interface"))
			// (.dns_port | verify("dns_port"))
			// (.mixed_port | verify("mixed_port"))
			// (.tun_mode | verify("tun_mode"))
			// (.log_level | verify("log_level"))
			// (.clash_api | verify("clash_api"))
			// (.allow_lan | verify("allow_lan"))
			// (.mixin | verify("mixin"))
			// (.service_mode | verify("service_mode"))
			// (.set_system_proxy | verify("set_system_proxy"))
			// (.start_at_boot | verify("start_at_boot"))
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

	lcoal sets='[
		"default_interface",
		"dns_port",
		"mixed_port",
		"tun_mode",
		"log_level",
		"clash_api",
		"allow_lan",
		"mixin",
		"service_mode",
		"set_system_proxy",
		"start_at_boot",
		"config"
	]'
	sets="$(jsonSelectjson settings \
		'def export($keys):
			def loop($i):
				if $i >= ($keys | length) then empty else
					if $keys[$i] then "local \($keys[$i])=\u0027\(.[$keys[$i]])\u0027"
					else "local \($keys[$i])=" end, loop($i+1)
				end;
			[loop(0)] | join(";");
		export($ARGS.positional[0])' \
		"$sets" \
	)"
	eval "$sets"

	# platform
	case "$OS" in
		windows)
			# set_system_proxy
			if [ "$set_system_proxy" = "true" ]; then
				reg add "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings" //v ProxyEnable //t REG_DWORD //d 1 //f
				[ -n "$mixed_port" ] &&
					reg add "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings" //v ProxyServer //t REG_SZ //d "127.0.0.1:$mixed_port" //f
				reg add "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings" //v ProxyOverride //t REG_SZ //d 'localhost;*.local;*.lan;127.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;172.20.*;172.21.*;172.22.*;172.23.*;172.24.*;172.25.*;172.26.*;172.27.*;172.28.*;172.29.*;172.30.*;172.31.*;192.168.*;<local>' //f
			else
				reg add "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings" //v ProxyEnable //t REG_DWORD //d 0 //f
			fi
			# start_at_boot
			if [ "$start_at_boot" = "true" ]; then
				# service_mode
				if [ "$service_mode" = "true" ]; then
					windows_service install
				else
					windows_startup install
				fi
			else
				windows_service uninstall
				windows_startup uninstall
			fi
		;;
		darwin)
		;;
		*)
		;;
	esac

}
