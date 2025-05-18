#!/usr/bin/env bash
set -euo pipefail

# This script fixes both install_wp.sh and setup_wp.sh scripts

echo "🔧 Fixing WordPress installation scripts..."

# First, let's look at the current setup to understand the issue
echo "📋 Checking current setup..."
ls -la /opt/infra-scripts/wordpress/

# 1. Fix the install_wp.sh script
echo "🔧 Creating fixed install_wp.sh script..."
cat > /opt/infra-scripts/wordpress/install_wp.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <subdomain>"
  exit 1
fi

SUB="$1"
DOMAIN="s-neue.website"
FQDN="${SUB}.${DOMAIN}"
VHOST_PATH="/etc/apache2/sites-available/${SUB}.conf"
WWW_PATH="/var/www/${SUB}"
TEST_MODE="${TEST_MODE:-false}"

echo "🔍 Prüfe DNS-A-Record für ${FQDN}…"

if [[ "$TEST_MODE" != "true" ]]; then
  # Only check DNS in normal mode
  if ! dig +short "${FQDN}" | grep -q '.'; then
    echo "⚠️ Kein A-Record für ${FQDN} gefunden. Bitte zuerst create_cf_sub_auto ausführen."
    exit 1
  fi
fi

echo "🔨 Erstelle Verzeichnisse…"
mkdir -p "${WWW_PATH}"
chown -R www-data:www-data "${WWW_PATH}"

echo "📝 Erstelle Apache vHost…"
cat > "${VHOST_PATH}" << VHOST
<VirtualHost *:80>
    ServerName ${FQDN}
    DocumentRoot ${WWW_PATH}
    
    <Directory ${WWW_PATH}>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/error-${SUB}.log
    CustomLog \${APACHE_LOG_DIR}/access-${SUB}.log combined
</VirtualHost>
VHOST

echo "🔄 Aktiviere Apache vHost…"
a2ensite "${SUB}.conf"
systemctl reload apache2

echo "📦 Installiere WordPress…"
cd "${WWW_PATH}"
wp core download --locale=de_DE --allow-root

# Erstelle wp-config.php
DB_NAME="${SUB}"
DB_USER="wordpressuser"
DB_PASS="password" # In der Praxis besser aus .env o.ä. lesen

echo "🗃️ Erstelle MySQL-Datenbank…"
mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;"
mysql -u root -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"

echo "🔧 Generiere wp-config.php…"
wp config create \
  --dbname="${DB_NAME}" \
  --dbuser="${DB_USER}" \
  --dbpass="${DB_PASS}" \
  --locale=de_DE \
  --allow-root

echo "🚀 Installiere WordPress-Core…"
wp core install \
  --url="http://${FQDN}" \
  --title="${SUB} - S Neue Website" \
  --admin_user="we-admin" \
  --admin_password="We-25-$$-Vo" \
  --admin_email="admin@online-aesthetik.de" \
  --skip-email \
  --allow-root

echo "✅ WordPress für ${SUB} erfolgreich installiert."
echo "🔗 URL: http://${FQDN}"
echo "👤 Admin: we-admin / We-25-$$-Vo"
EOF
chmod +x /opt/infra-scripts/wordpress/install_wp.sh

# 2. Fix the setup_wp.sh test mode script
echo "🔧 Creating improved test mode script..."
cat > /opt/infra-scripts/test-mode.sh << 'EOF'
#!/bin/bash
set -euo pipefail

if [ "$1" == "enable" ]; then
  echo "Enabling test mode..."
  # Backup the original file if not already backed up
  if [ ! -f "/opt/infra-scripts/wordpress/setup_wp.sh.orig" ]; then
    cp /opt/infra-scripts/wordpress/setup_wp.sh /opt/infra-scripts/wordpress/setup_wp.sh.orig
  fi
  
  # Create a modified version that skips DNS check
  cat > /opt/infra-scripts/wordpress/setup_wp.sh << 'TEST_MODE'
#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <subdomain>"
  exit 1
fi

SUB="$1"

# Hartkodiertes Repo-Verzeichnis
INFRA_DIR="/opt/infra-scripts"

echo "🌐 TEST MODE: Simuliere Subdomain $SUB…"
echo "✅ TEST MODE: DNS-Check übersprungen."

echo "📦 Installiere WordPress für $SUB…"
# Setze TEST_MODE=true für install_wp.sh
export TEST_MODE=true
bash "$INFRA_DIR/wordpress/install_wp.sh" "$SUB"

echo "✅ setup_wp für $SUB abgeschlossen."
TEST_MODE
  chmod +x /opt/infra-scripts/wordpress/setup_wp.sh
  
  echo "✅ Test mode enabled. DNS checks will be bypassed."
  echo "Run 'setup_wp testkunde1' to test installation."
  
elif [ "$1" == "disable" ]; then
  echo "Disabling test mode..."
  if [ -f "/opt/infra-scripts/wordpress/setup_wp.sh.orig" ]; then
    cp /opt/infra-scripts/wordpress/setup_wp.sh.orig /opt/infra-scripts/wordpress/setup_wp.sh
    echo "✅ Original setup script restored."
  else
    echo "❌ Original backup not found. Cannot restore."
  fi
else
  echo "Usage: $0 {enable|disable}"
  exit 1
fi
EOF
chmod +x /opt/infra-scripts/test-mode.sh

# 3. Fix the normal setup_wp.sh script
echo "🔧 Fixing normal setup_wp.sh script..."
cat > /opt/infra-scripts/wordpress/setup_wp.sh.fixed << 'EOF'
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
# Run create_cf_sub_auto and capture output
CF_OUTPUT=$("$INFRA_DIR/cloudflare/create_cf_sub_auto.sh" "$BASE")
echo "$CF_OUTPUT"

# Extract subdomain from output using simpler pattern
SUB=$(echo "$CF_OUTPUT" | grep -o "\b${BASE}[0-9]*\b" || echo "$BASE")

echo "⏳ Warte auf DNS-Aktivierung von ${SUB}.s-neue.website …"
SERVER_IP=$(curl -s https://ifconfig.me)
for i in {1..10}; do
  if dig +short "${SUB}.s-neue.website" | grep -q "$SERVER_IP"; then
    echo "✅ DNS-A-Record aktiv."
    break
  fi
  echo "⏳ Warte auf DNS Propagation... Versuch $i von 10"
  sleep 3
done

echo "📦 Installiere WordPress für $SUB…"
# 3) Echte Install-Funktion mit absolutem Pfad aufrufen
export TEST_MODE=false
bash "$INFRA_DIR/wordpress/install_wp.sh" "$SUB"

echo "✅ setup_wp für $SUB abgeschlossen."
EOF

# 4. Determine if we should restore the original or use the fixed version
if [ -f "/opt/infra-scripts/wordpress/setup_wp.sh.orig" ]; then
  echo "🔄 Original setup_wp.sh found, replacing with fixed version..."
  cp /opt/infra-scripts/wordpress/setup_wp.sh.fixed /opt/infra-scripts/wordpress/setup_wp.sh.orig
  echo "✅ Fixed normal setup_wp.sh. It will be used when test mode is disabled."
else
  echo "🔄 Replacing current setup_wp.sh with fixed version..."
  cp /opt/infra-scripts/wordpress/setup_wp.sh.fixed /opt/infra-scripts/wordpress/setup_wp.sh
  echo "✅ Fixed normal setup_wp.sh."
fi

chmod +x /opt/infra-scripts/wordpress/setup_wp.sh.fixed
rm /opt/infra-scripts/wordpress/setup_wp.sh.fixed

# 5. Set up Cloudflare configuration with actual tokens
echo "☁️ Setting up Cloudflare configuration with tokens..."
cat > /etc/profile.d/cloudflare.sh << 'EOF'
# Cloudflare configuration
export CF_API_TOKEN="lLrGrv3Q8hmj-Db4ncotnGqbaE0IFX9oKvD8yxQV"
export ZONE_ID="d7e5b4cfe310063ede065b1ba06bcdf7" 
export DOMAIN="s-neue.website"
EOF
chmod +x /etc/profile.d/cloudflare.sh
source /etc/profile.d/cloudflare.sh

echo "✅ All scripts fixed successfully!"
echo ""
echo "To test WordPress installation WITHOUT DNS checks:"
echo "1. Enable test mode:  bash /opt/infra-scripts/test-mode.sh enable"
echo "2. Run setup:         setup_wp testkunde1"
echo ""
echo "For REAL DNS usage, follow these steps:"
echo "1. Edit /etc/profile.d/cloudflare.sh and add your actual Cloudflare credentials"
echo "2. Run:               source /etc/profile.d/cloudflare.sh"
echo "3. Disable test mode: bash /opt/infra-scripts/test-mode.sh disable"
echo "4. Run setup:         setup_wp testkunde1"
echo ""
echo "Note: MySQL database user 'wordpressuser' with password 'password' will be used"
echo "      You may want to change this in the install_wp.sh script for security"