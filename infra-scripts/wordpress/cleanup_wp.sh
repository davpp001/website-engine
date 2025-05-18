#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <subdomain>"
  exit 1
fi

SUB=$1

# 1) HARDCODED Pfad zu deinem Infra-Repo
INFRA_DIR="/opt/infra-scripts"

# 2) Ins Repo wechseln und Pull
cd "$INFRA_DIR"
git pull --ff-only origin main

echo "🧹 Entferne WordPress und DNS für $SUB..."

# 3) Skripte mit absolutem Pfad ausführen
bash "$INFRA_DIR/wordpress/uninstall_wp.sh" "$SUB"
bash "$INFRA_DIR/cloudflare/delete_cf_sub.sh" "$SUB"

# 4) Default-Site wieder aktivieren & Apache neu laden
sudo a2ensite 000-default.conf || true
sudo systemctl reload apache2

echo "✅ $SUB vollständig entfernt."