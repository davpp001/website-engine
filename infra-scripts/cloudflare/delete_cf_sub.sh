#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <subdomain>" >&2
  exit 1
fi

SUB=$1
TOKEN=$CF_API_TOKEN
ZONE=$ZONE_ID
DOMAIN="s-neue.website"
FQDN="${SUB}.${DOMAIN}"

echo "🔍 Suche A-Records für ${FQDN}…"
IDS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE}/dns_records?type=A&name=${FQDN}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" | jq -r '.result[]?.id')

if [ -z "$IDS" ]; then
  echo "⚠️ Kein Record gefunden für ${FQDN}."
  exit 0
fi

for id in $IDS; do
  echo "🗑️ Lösche Record ID $id…"
  curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${ZONE}/dns_records/${id}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" > /dev/null
  echo "   → gelöscht."
done

echo "✅ Alle Records für ${FQDN} gelöscht."
