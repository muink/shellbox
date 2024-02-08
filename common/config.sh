#!/bin/bash
# Copyright (C) 2024 Anya Lin
#
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.
#

# func <provider_number> <filter>
filterVerify() {
	local i="$1" filter="$2" filter_field
	[ "$(jsonSelect filter 'type')" = "array" ] || { logs warn "updateProvider: Filter of provider [$i] is invalid.\n"; return 1; }
	for f in $(seq 0 $[ $(jsonSelect filter 'length') -1 ]); do
		filter_field="$(jsonSelect filter ".[$f]")"
		if isEmpty filter_field || [ "$(jsonSelect filter_field 'type')" != "object" ]; then
			logs warn "updateProvider: Field [$f] of the filter for provider [$i] is invalid.\n"
			return 1
		fi
		# Field check
		echo "$(jsonSelect filter_field '.action')" | grep -qE "^(include|exclude)$" ||
			{ logs warn "updateProvider: Invalid value of key 'action' for filter field [$f] for provider [$i].\n"; return 1; }
		[ "$(jsonSelect filter_field '(.regex|type) == "string"')" = "true" ] ||
			{ logs warn "updateProvider: Invalid value of key 'regex' for filter field [$f] for provider [$i].\n"; return 1; }
	done
}

updateProvider() {
	[ -x "$(command -v "$SINGBOX")" ] || { logs err "sing-box is not installed.\n"; return 1; }
	local setting="$(cat "$MAINSET")"
	isEmpty "$(jsonSelect setting '.providers')" && { logs err "updateProvider: No subscription available. Update failed.\n"; return 1; }

	local provider providers="$(jsonSelect setting '.providers')" count=0
	local url tag ua filter

	local time=$($DATE -u +%s%3N)
	for i in $(seq 0 $[ $(jsonSelect providers 'length') -1 ]); do
		provider="$(jsonSelect providers ".[$i]")"
		[ "$(jsonSelect provider 'type')" = "object" ] || { logs warn "updateProvider: '$provider' is not a valid provider.\n"; continue; }
		# Required
		for k in url tag; do
			eval "isEmpty \"\$(jsonSelect provider '.$k')\" && \
				{ logs warn \"updateProvider: '\$provider' lost '$k' key.\n\"; continue; } || \
				$k=\"\$(jsonSelect provider '.$k')\""
		done
		# Optional
		for k in ua filter; do
			eval "isEmpty \"\$(jsonSelect provider '.$k')\" || \
				$k=\"\$(jsonSelect provider '.$k')\""
		done
		# Filter Verify
		if isEmpty "$filter"; then
			unset filter
		else
			filterVerify "$i" "$filter" || continue
		fi
		# Updating
		local result UA="$ua" FILTER="$filter"
		parse_subscription result "$url" "$filter" || continue
		echo -n "$result" > "$SUBSDIR/$tag.json"
		let count++
	done
	time=$[ $($DATE -u +%s%3N) - $time ]
	logs yeah "Successfully updated $count providers of total $(jsonSelect providers 'length').\n"
	logs yeah "Total time: $[ $time / 60000 ]m$[ $time / 1000 % 60 ]s$[ $time % 1000 ]ms.\n"
}
