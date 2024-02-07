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
        { "action": "exclude", "keywords": [ "海外用户|回国" ] }
      ]
    },
    {
      "url": "https://raw.githubusercontent.com/ermaozi/get_subscribe/main/subscribe/v2ray.txt", // Required.
      "tag": "sub_2", // Required. Used to add the all nodes currently subscription to outbounds field. E.g "outbounds": [ "{sub_2}" ]
      "subgroup": "✈️ erma", // Optional. Add a selector node that includes all nodes currently subscription
      "prefix": "[erma] ", // Optional. Add prefix for all nodes currently subscription.
      "ua": "passwall", // Optional. Sent User-Agent.
      "filter": [ // Optional. Pre-filter nodes.
        { "action": "include", "keywords": [ "🇸🇬|SG|sg|Singapore|新加坡|狮城" ] }
      ]
    }
  ],
  "configs": [
    {
      "output": "ruleset_tun.json", // Required. The target file to build.
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
  "quicksettings": {
    "default_interface": "",
    "log_level": "info", // "trace", "debug", "info", "warn", "error", "fatal", "panic"
    "dns_port": 2153, // The first inbound will be overwritten.
    "mixed_port": 2188, // The first inbound will be overwritten.
    "ipv6": true,
    "allow_lan": true,
    "set_system_proxy": true,
    "service_mode": false,
    "start_at_boot": false,
    "clash_api": {
      "external_controller": "[::1]:19988",
      "secret": ""
    },
    "config": "ruleset_tun.json"
  }
}
```
