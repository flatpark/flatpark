#!/usr/bin/env bash
set -euo pipefail
page=$(curl -fsSL --retry 3 https://saturnpcb.com/saturn-pcb-toolkit/)
version=$(printf '%s\n' "$page" | sed -nE 's/.*Saturn PCB Design Toolkit Version ([0-9]+\.[0-9]+).*/\1/p' | head -n1)
[[ "$version" =~ ^[0-9]+\.[0-9]+$ ]] || { echo 'Could not find toolkit version' >&2; exit 1; }
url="https://www.saturnpcb.com/wp-content/Toolkit/Saturn_PCB_Toolkit_V${version}_Setup_MSI.msi"
curl -fsSI --retry 3 "$url" >/dev/null
jq -n --arg v "$version" --arg u "$url" '{version:$v, sources:[{filename:"saturn.msi",url:$u}]}'
