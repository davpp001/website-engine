#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <subdomain>"
  exit 1
fi

BASE="$1"

# 1) Hartkodiertes Repo-Verzeichnis
INFRA_DIR="/opt/infra-scripts"

# 2) Ins Repo wechseln und aktuellen Code holen
# cd "$INFRA_DIR"
# git pull --ff-only origin main

echo "🌐 Erstelle Subdomain $BASE…"
SUB=$(bash "$INFRA_DIR/cloudflare/create_cf_sub_auto.sh" "$BASE" \
  | grep -oP '(?<=Subdomain\s)[a-zA-Z0-9-]+(?=\.s-neue\.website)')

echo "⏳ Warte auf DNS-Aktivierung von ${SUB}.s-neue.website …"
for i in {1..10}; do
  if dig +short "${SUB}.s-neue.website" | grep -q '217.160.252.118'; then
    echo "✅ DNS-A-Record aktiv."
    break
  fi
  sleep 2
done

echo "📦 Installiere WordPress für $SUB…"
# 3) Echte Install-Funktion mit absolutem Pfad aufrufen
bash "$INFRA_DIR/wordpress/install_wp.sh" "$SUB"

echo "✅ setup_wp für $SUB abgeschlossen."