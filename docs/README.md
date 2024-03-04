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
    "default_interface": "",
    "dns_port": 2153, // inbounds[] will be overwritten.
    "mixed_port": 2188, // inbounds[] will be overwritten.
    "tun_mode": false, // inbounds[] will be overwritten.
    "log_level": "info", // "trace", "debug", "info", "warn", "error", "fatal", "panic"
    "clash_api": {
      "controller_port": 19988,
      "secret": ""
    },
    "allow_lan": true,
    "mixin": true, // If false, the above fields will not be applyed
    "service_mode": false,
    "set_system_proxy": true, // 127.0.0.1:$mixed_port
    "start_at_boot": false,
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
