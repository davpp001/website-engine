#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <subdomain>" >&2
  exit 1
fi

SUB=$1
DB_USER="wp_${SUB}_user"
DB_NAME="wp_${SUB}"
DOCROOT="/var/www/${SUB}"

echo "🔧 Deaktiviere Apache vHost…"
sudo a2dissite "$SUB.conf" || true
sudo a2dissite "$SUB-le-ssl.conf" || true

echo "🧹 Lösche Verzeichnis $DOCROOT…"
sudo rm -rf "$DOCROOT"

echo "🗑️ Lösche MySQL-Datenbank & Benutzer…"
sudo mysql <<EOF
DROP DATABASE IF EXISTS \`${DB_NAME}\`;
DROP USER IF EXISTS '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

echo "♻️ Starte Apache neu…"
sudo systemctl reload apache2

echo "✅ WordPress-Instanz für $SUB erfolgreich entfernt."
