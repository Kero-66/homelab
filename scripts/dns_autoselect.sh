#!/usr/bin/env bash
set -euo pipefail

# dns_autoselect.sh
# Benchmarks a list of DNS servers (default Cloudflare + Google) and
# applies the fastest ordering to the system resolver.
#
# Usage:
#  sudo ./scripts/dns_autoselect.sh            # run with defaults
#  sudo ./scripts/dns_autoselect.sh "8.8.8.8 1.1.1.1 9.9.9.9"  # custom list
#
# To run periodically, create a systemd timer or cronjob that runs as root.

SERVERS_IN=${1:-"1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4"}
DOM=${DNS_TEST_DOMAIN:-www.google.com}
TRIES=${DNS_TRIES:-3}
TIMEOUT=${DNS_TIMEOUT:-2}

if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root (sudo)." >&2
  exit 2
fi

command -v dig >/dev/null 2>&1 || { echo "dig is required. Install dnsutils (Debian/Ubuntu) or bind-utils (RHEL)." >&2; exit 3; }

measure() {
  local server=$1
  local -a times
  for i in $(seq 1 $TRIES); do
    out=$(dig +time=$TIMEOUT +tries=1 +stats @$server "$DOM" 2>/dev/null || true)
    rt=$(printf "%s" "$out" | awk -F': ' '/Query time/ {print $2; exit}' | awk '{print $1}')
    if [ -n "$rt" ]; then
      times+=("$rt")
    fi
  done
  if [ ${#times[@]} -eq 0 ]; then
    printf "%s" "9999"
    return
  fi
  # compute median
  IFS=$'\n' sorted=( $(printf "%s\n" "${times[@]}" | sort -n) )
  mid=$(( ${#sorted[@]} / 2 ))
  printf "%s" "${sorted[$mid]}"
}

declare -A latmap
for srv in $SERVERS_IN; do
  lat=$(measure $srv)
  latmap[$srv]=$lat
  printf "%s -> %sms\n" "$srv" "$lat"
done

# Sort servers by latency (numeric)
ordered=$(for k in "${!latmap[@]}"; do printf "%s %s\n" "${latmap[$k]}" "$k"; done | sort -n | awk '{print $2}' | tr '\n' ' ')

echo "Selected order: $ordered"

# Prefer systemd-resolved/resolvectl when available
if command -v resolvectl >/dev/null 2>&1 && systemctl is-active --quiet systemd-resolved; then
  # find outgoing interface (best-effort)
  iface=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++){ if($i=="dev"){print $(i+1); exit}}}') || true
  if [ -n "$iface" ]; then
    echo "Applying via resolvectl on interface: $iface"
    resolvectl dns "$iface" $ordered
    resolvectl flush-caches || true
    echo "Done."
    exit 0
  fi
fi

# Fallback: overwrite /etc/resolv.conf (backup first)
ts=$(date +%s)
bak=/etc/resolv.conf.bak.$ts
cp -a /etc/resolv.conf "$bak" && echo "Backed up /etc/resolv.conf -> $bak"

{
  for s in $ordered; do
    echo "nameserver $s"
  done
} > /etc/resolv.conf

echo "Wrote /etc/resolv.conf with fastest order."

exit 0
