#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <subdomain-base>"
  exit 1
fi

BASE="$1"
ZONE="s-neue.website"
IP="$(curl -s https://ifconfig.me)"
TTL=120

: "${CF_API_TOKEN:?Bitte CF_API_TOKEN exportieren}"
: "${ZONE_ID:?Bitte ZONE_ID exportieren}"

SUB="$BASE"
SUF=1
while :; do
  FQDN="$SUB.$ZONE"
  cnt=$(curl -s -X GET \
    "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A&name=$FQDN" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" \
    | jq -r '.result | length')

  if [ "$cnt" -eq 0 ]; then
    resp=$(curl -s -X POST \
      "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
      -H "Authorization: Bearer $CF_API_TOKEN" \
      -H "Content-Type: application/json" \
      --data '{
        "type":"A",
        "name":"'"$SUB"'",
        "content":"'"$IP"'",
        "ttl":'"$TTL"',
        "proxied":false
      }')
    ok=$(echo "$resp" | jq -r '.success')
    if [ "$ok" = "true" ]; then
      echo "✅ Subdomain $FQDN angelegt und zeigt auf $IP."
      exit 0
    else
      echo "❌ Fehler: $(echo "$resp" | jq -r '.errors[].message')"
      exit 2
    fi
  fi

  SUF=$((SUF+1))
  SUB="$BASE$SUF"
done

echo "$SUB"