#!/bin/bash
# Copyright (C) 2024 Anya Lin
#
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.
#

# func <providers>
verifyProviders() {
	local providers="$1" rcode

	if [ -n "$providers" ]; then
		rcode="$(jsonSelect providers \
			'if (type != "array") or (length == 0) then "No providers available." else
				. as $providers |
				last(
					label $out | foreach range(length) as $i (null;
						$providers[$i] |
						if (type != "object") or (length == 0) then "Provider [" + ($i|tostring) + "] is invalid.", break $out else
							. as $provider |
							# Required
							last(
								label $required | ["url","tag"] | foreach .[] as $k (null;
									$provider[$k] |
									if ($k == "url") then
										if (type == "string") and (length > 0) then 0 else
											"Key [\"url\"] of the provider [" + ($i|tostring) + "] is invalid.", break $required
										end
									elif ($k == "tag") then
										if (type == "string") and (length > 0) and test("^([[:word:]]+)$") then 0 else
											"Key [\"tag\"] of the provider [" + ($i|tostring) + "] is invalid.", break $required
										end
									else 0 end
								)
							) |
							if . != 0 then ., break $out else
								# Optional
								$provider | keys_unsorted |
								last(
									label $optional | foreach .[] as $k (null;
										if ($k | test("^(prefix|ua)$") ) then
											$provider[$k] |
											if type == "null" then 0
											elif type == "string" then 0 else
												"Key [\"" + $k + "\"] of the provider [" + ($i|tostring) + "] is invalid.", break $optional
											end
										elif $k == "subgroup" then
											$provider[$k] |
											if (type == "string") and (length > 0) then 0
											elif type == "array" then
												. as $subgroups |
												last(
													label $optional_subgroup | foreach range(length) as $q (null;
														$subgroups[$q] |
														if (type == "string") and (length > 0) then 0
														else "Invalid field [" + ($q|tostring) + "] of the key [\"" + $k + "\"] of the provider [" + ($i|tostring) + "] is invalid.", break $optional_subgroup end
													)
												) |
												if . == 0 then 0 else ., break $optional end
											else "Key [\"" + $k + "\"] of the provider [" + ($i|tostring) + "] is invalid.", break $optional end
										elif $k == "filter" then
											$provider[$k] |
											if type != "array" then "Filters of the provider [" + ($i|tostring) + "] is invalid.", break $optional else
												if length == 0 then 0 else
													. as $filters |
													last(
														label $optional_filter | foreach range(length) as $q (null;
															$filters[$q] |
															if (type == "object") and (length > 0) then
																# Field check
																if ((.action|type) != "string") or (.action | test("^(include|exclude)$") | not) then
																	"Invalid field of the key [\"action\"] for filter [" + ($q|tostring) + "] for provider [" + ($i|tostring) + "].", break $optional_filter
																elif (.regex|type) != "string" then
																	"Invalid field of the key [\"regex\"] for filter [" + ($q|tostring) + "] for provider [" + ($i|tostring) + "].", break $optional_filter
																else 0 end
															else "Filter [" + ($q|tostring) + "] of the provider [" + ($i|tostring)+ "] is invalid.", break $optional_filter end
														)
													) |
													if . == 0 then 0 else ., break $optional end
												end
											end
										else 0 end
									)
								) |
								if . == 0 then 0 else ., break $out end
							end
						end
					)
				)
			end' \
		)"
	else
		rcode="No providers available."
	fi

	[ "$rcode" = "0" ] || { logs err "verifyProviders: $rcode\n"; return 1; }
	return 0
}

updateProvider() {
	[ -x "$(command -v "$SINGBOX")" ] || { logs err "sing-box is not installed.\n"; return 1; }
	local setting="$(cat "$MAINSET")"
	local providers="$(jsonSelect setting '.providers')"
	verifyProviders "$providers" || return 1

	local provider provider_count="$(jsonSelect providers 'length')" count=0
	local node_result UA FILTER

	local time=$($DATE -u +%s%3N)
	for i in $(seq 0 $[ $provider_count -1 ]); do
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
	time=$[ $($DATE -u +%s%3N) - $time ]
	logs yeah "Successfully updated $count providers of total $provider_count.\n"
	logs yeah "Total time: $[ $time / 60000 ]m$[ $time / 1000 % 60 ]s$[ $time % 1000 ]ms.\n"
}
