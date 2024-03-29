# Configuration document

## Main config `settings.json`

``` json
{
  "providers": [
    {
      "url": "https:/gist.githubusercontent.com/Toperlock/b1ca381c32820e8c79669cbbd85b68ac/raw/dafae92fbe48ff36dae6e5172caa1cfd7914cda4/gistfile1.txt", // Required.
      "tag": "sub_1", // Required. Used to add the all nodes currently subscription to outbounds field. E.g "outbounds": [ "{sub_1}" ]
      "subgroup": [ // Optional. Add multiple selector nodes that includes all nodes currently subscription
        "✈️ Toper",
        "✈️ Toperx"
      ],
      "prefix": "❤️ Toper - ", // Optional. Add prefix for all nodes currently subscription.
      "ua": "v2rayng", // Optional. Sent User-Agent.
      "filter": [ // Optional. Pre-filter nodes.
        { "action": "exclude", "regex": "海外用户|回国" }
        // Filters are matched from front to back. Once the expression is matched successfully, subsequent filters will be ignored.
      ]
    },
    {
      "url": "https://raw.githubusercontent.com/ermaozi/get_subscribe/main/subscribe/v2ray.txt", // Required.
      "tag": "sub_2", // Required. Used to add the all nodes currently subscription to outbounds field. E.g "outbounds": [ "{sub_2}" ]
      "subgroup": "✈️ erma", // Optional. Add a selector node that includes all nodes currently subscription
      "prefix": "[erma] ", // Optional. Add prefix for all nodes currently subscription.
      "ua": "passwall", // Optional. Sent User-Agent.
      "filter": [ // Optional. Pre-filter nodes.
        { "action": "include", "regex": "🇸🇬|SG|sg|Singapore|新加坡|狮城" } // The action of the first filter will be used as the default action.
      ]
    }
  ],
  "configs": [
    {
      "output": "ruleset_tun", // Required. The target file to build.
      "enabled": true, // Required. Build or not.
      "providers": [ // Required. Providers to import.
        "sub_1", // .providers[0].tag
        "sub_2"
      ],
      "templates": [ // Required. Template snippets. When merging arrays, overwriting will be performed instead of merging.
        "log.json",
        "dns.json",
        "ntp.json",
        "inbounds.json",
        "outbounds.json",
        "route.json",
        "experimental.json"
      ]
    }
  ],
  "settings": {
    "default_interface": "", // null:keepOriginal, "":auto gen by shellbox, "en0":en0
    "sniff_override_destination": false, // null:keepOriginal, false:disable, true:enable
    "log_level": "info", // null:keepOriginal, "":keepOriginal, "trace", "debug", "info", "warn", "error", "fatal", "panic"
    "dns_port": 2153, // null:keepOriginal, 2153: add a dns_in on port 2153
    "mixed_in": {
      "enabled": true, // null:keepOriginal, false:keepOriginal, true: add a mixed_in on port 2188
      "port": 2188, // Required
      "set_system_proxy": false // null:keepOriginal, false:disable, true:enable
    },
    "tun_in": { // Required install as service when using tun
      "enabled": false, // null:keepOriginal, false:disableAll, true:overwriteAll by shellbox
      "endpoint_independent_nat": false, // null:keepOriginal, false:disablel, true:enable
      "udp_timeout": "5m", // null:keepOriginal, "":keepOriginal, "5m":5m
      "stack": "mixed" // null:keepOriginal, "":keepOriginal, "system", "gvisor", "mixed"
    },
    "clash_api": {
      "external_controller": "127.0.0.1:19988", // null:keepOriginal, "":keepOriginal, "127.0.0.1:19988":127.0.0.1:19988
      "secret": "" // null:keepOriginal, "":auto gen by shellbox, "typepassword":typepassword
    },
    "mixin": true, // If false, the above fields will not be applyed, the runtime config will remain as is
    "service_mode": false, // If you shellbox on a removable storage device, the program may not start
    "start_at_boot": false, // If you shellbox on a removable storage device, the program may not start
    "shortcut": false,
    "config": "ruleset_tun"
  }
}
```

## Templates

``` json
{
  "outbounds": [
    {
      "type": "selector",
      "tag": "Proxy",
      "outbounds": [
        "Auto",
        "🇸🇬 SG Nodes",
        "{all_group}" // {all_group}: all subscriptions's selector nodes, will be ignore if subgroup not seted
      ],
      "default": "Auto"
    },
    {
      "type": "selector",
      "tag": "Netfilx",
      "outbounds": [
        "Auto",
        "🇸🇬 SG Nodes",
        "{sub_1_group}" // {sub_1_group}: all sub_1's selector nodes, will be ignore if subgroup not seted
      ],
      "default": "Auto"
    },
    {
      "type": "urltest",
      "tag": "Auto",
      "outbounds": [
        "{all}" // {all}: all subscriptions's nodes
      ],
      "url": "https://www.gstatic.com/generate_204",
      "interval": "15m"
    },
    {
      "type": "selector",
      "tag": "🇸🇬 SG Nodes",
      "outbounds": [
        "{sub_1}", // {sub_1}: all sub_1's nodes
        "{sub_2}" // {sub_2}: all sub_2's nodes
      ],
      "filter": [ // Optional filter
        { "action": "include", "regex": "🇸🇬|SG|sg|Singapore|新加坡|狮城" }
      ]
    }
  ]
}
```
