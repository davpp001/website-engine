#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <subdomain>" >&2
  exit 1
fi

SUB=$1
TOKEN=$CF_API_TOKEN
ZONE=$ZONE_ID
DOMAIN="s-neue.website"
FQDN="${SUB}.${DOMAIN}"
DOCROOT="/var/www/${SUB}"

# Feste Credentials
DB_USER="we-admin"
DB_PASS='We-25-$$-Vo'
WP_USER="${DB_USER}"
WP_PASS="${DB_PASS}"
WP_EMAIL="admin@online-aesthetik.de"

# 0) DNS prüfen
echo "🔍 Prüfe DNS-A-Record für ${FQDN}…"
RECORDS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE}/dns_records?type=A&name=${FQDN}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  | jq -r '.result[]?.id')
if [ -z "$RECORDS" ]; then
  echo "⚠️ Kein A-Record für ${FQDN} gefunden. Bitte zuerst create_cf_sub_auto ausführen."
  exit 1
fi

# 1) Webroot anlegen
sudo mkdir -p "${DOCROOT}"
sudo chown -R www-data:www-data "${DOCROOT}"

# 2) VHost anlegen
sudo tee /etc/apache2/sites-available/${SUB}.conf > /dev/null << VHOST_EOF
<VirtualHost *:80>
  ServerName ${FQDN}
  Redirect permanent / https://${FQDN}/
</VirtualHost>

<VirtualHost *:443>
  ServerName ${FQDN}
  DocumentRoot ${DOCROOT}

  SSLEngine on
  SSLCertificateFile /etc/letsencrypt/live/s-neue.website/fullchain.pem
  SSLCertificateKeyFile /etc/letsencrypt/live/s-neue.website/privkey.pem

  <Directory ${DOCROOT}>
    AllowOverride All
    Require all granted
  </Directory>
</VirtualHost>
VHOST_EOF

# 3) Site aktivieren & Apache neu laden
sudo a2ensite "${SUB}.conf"
sudo systemctl reload apache2

# 4) Datenbank & User anlegen
DB_NAME="wp_${SUB//./_}"
sudo mysql << SQL_EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL_EOF

# 5) WP-CLI installieren & Setup
sudo -u www-data wp core download --path="${DOCROOT}"
sudo -u www-data wp config create --path="${DOCROOT}" \
  --dbname="${DB_NAME}" --dbuser="${DB_USER}" --dbpass="${DB_PASS}"
sudo -u www-data wp core install --path="${DOCROOT}" \
  --url="http://${FQDN}" \
  --title="WP ${SUB}" \
  --admin_user="${WP_USER}" \
  --admin_password="${WP_PASS}" \
  --admin_email="${WP_EMAIL}"

echo "✅ WordPress unter http://${FQDN} mit User ${WP_USER} und E-Mail ${WP_EMAIL} installiert."

sudo systemctl reload apache2

echo "🌐 Öffne im Browser: https://${FQDN}"