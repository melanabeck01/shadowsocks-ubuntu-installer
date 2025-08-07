#!/bin/bash
cfg=${1:-/etc/shadowsocks-libev/config.json}
[[ ! -f $cfg ]] && cfg="$(dirname $0)/test-config.json"
[[ ! -f $cfg ]] && { echo "Config not found"; exit 1; }
command -v jq >/dev/null || { echo "jq required"; exit 1; }
srv=$(curl -s --max-time 5 ip.me 2>/dev/null||curl -s --max-time 5 ifconfig.me 2>/dev/null||hostname -I|awk '{print $1}'|tr -d ' ')
mtd=$(jq -r '.method//empty' $cfg)
pwd=$(jq -r '.password//empty' $cfg)
prt=$(jq -r '.server_port//empty' $cfg)
[[ -z "$mtd$pwd$prt" ]] && { echo "Invalid config"; exit 1; }
b64=$(echo -n "$mtd:$pwd"|base64 -w0)
echo "ss://$b64@$srv:$prt#SS-$(hostname -s)"