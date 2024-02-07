#!/bin/bash
# Copyright (C) 2024 Anya Lin
#
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.
#

updateProvider() {
	[ -x "$(command -v "$SINGBOX")" ] || { logs err "sing-box is not installed.\n"; return 1; }
	local setting="$(cat "$MAINSET")"
	isEmpty "$(jsonSelect setting '.providers')" && { logs err "updateProvider: No subscription available. Update failed.\n"; return 1; }

	local provider providers="$(jsonSelect setting '.providers')" count=0
	local url tag ua filter

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
		# Updating
		local result UA="$ua" FILTER="$filter"
		parse_subscription result "$url" "$filter" || continue
		echo -n "$result" > "$SUBSDIR/$tag.json"
		let count++
	done

	logs yeah "Successfully updated $count providers of total $(jsonSelect providers 'length').\n"
}
