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

	local JQFUNC_provider='def provider:
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

	local JQFUNC_providers='def providers:
		def loop($i):
			if $i >= length then empty else (.[$i] | provider | gsub("\\$i"; "\($i)")) // loop($i+1) end;
		if type == "array" and length > 0 then loop(0)
		else "No providers available." end;'

	if [ -n "$providers" ]; then
		rcode="$(jsonSelect providers "$JQFUNC_subgroup $JQFUNC_filter $JQFUNC_provider $JQFUNC_providers providers" )"
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
			eval "$k=\"\$(jsonSelect provider '.$k')\""
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
		if type == "string" and test("^[[:word:]\\.]+$") then empty
		elif type == "array" and length > 0 then loop(0)
		else 1 end;'

	local JQFUNC_config='def config:
		def verify($k):
			# Required
			if $k == "output" then
				if type == "string" and test("^[[:word:]\\.]+$") then empty else 1 end
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

	local JQFUNC_configs='def configs:
		def loop($i):
			if $i >= length then empty else (.[$i] | config | gsub("\\$i"; "\($i)")) // loop($i+1) end;
		if type == "array" and length > 0 then loop(0)
		else "No configs available." end;'

	if [ -n "$configs" ]; then
		rcode="$(jsonSelect configs "$JQFUNC_providers $JQFUNC_templates $JQFUNC_config $JQFUNC_configs configs" )"
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

	echo tag subgroup prefix
}
