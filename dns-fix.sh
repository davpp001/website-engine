#!/usr/bin/env bash
set -euo pipefail

# This script fixes DNS checking issues

echo "🔧 Fixing DNS check issues..."

# 1. First, let's test the actual DNS resolution
echo "🔍 Testing DNS resolution..."
DOMAIN="s-neue.website"
TEST_SUBDOMAIN="testkunde3"
FQDN="${TEST_SUBDOMAIN}.${DOMAIN}"

echo "Testing dig command for ${FQDN}:"
dig +short "${FQDN}"

echo "Testing dig with Cloudflare's DNS servers:"
dig +short @1.1.1.1 "${FQDN}"

# 2. Fix the install_wp.sh script to be more permissive with DNS checks
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

echo "🔍 Prüfe DNS-A-Record für ${FQDN}..."

# In test mode, skip DNS checks entirely
if [[ "$TEST_MODE" == "true" ]]; then
  echo "🧪 Test-Modus: DNS-Prüfung übersprungen."
else
  # Try different DNS servers and methods
  if dig +short "${FQDN}" | grep -q '[0-9]'; then
    echo "✅ DNS-Record gefunden via Standard-DNS."
  elif dig +short @1.1.1.1 "${FQDN}" | grep -q '[0-9]'; then
    echo "✅ DNS-Record gefunden via Cloudflare DNS (1.1.1.1)."
  elif dig +short @8.8.8.8 "${FQDN}" | grep -q '[0-9]'; then
    echo "✅ DNS-Record gefunden via Google DNS (8.8.8.8)."
  elif curl -s "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=A&name=${FQDN}" \
       -H "Authorization: Bearer ${CF_API_TOKEN}" | grep -q "\"name\":\"${FQDN}\""; then
    echo "✅ DNS-Record in Cloudflare gefunden, aber noch nicht propagiert. Fortfahren..."
  else
    echo "⚠️ Kein A-Record für ${FQDN} gefunden. Bitte zuerst create_cf_sub_auto ausführen."
    echo "Willst du trotzdem fortfahren? (j/n)"
    read -r response
    if [[ "$response" != "j" ]]; then
      exit 1
    fi
    echo "Fahre auf eigenes Risiko fort..."
  fi
fi

echo "🔨 Erstelle Verzeichnisse..."
mkdir -p "${WWW_PATH}"
chown -R www-data:www-data "${WWW_PATH}"

echo "📝 Erstelle Apache vHost..."
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

echo "🔄 Aktiviere Apache vHost..."
a2ensite "${SUB}.conf"
systemctl reload apache2

echo "📦 Installiere WordPress..."
cd "${WWW_PATH}"
wp core download --locale=de_DE --allow-root

# Erstelle wp-config.php
DB_NAME="${SUB}"
DB_USER="wordpressuser"
DB_PASS="password" # In der Praxis besser aus .env o.ä. lesen

echo "🗃️ Erstelle MySQL-Datenbank..."
mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;"
mysql -u root -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"

echo "🔧 Generiere wp-config.php..."
wp config create \
  --dbname="${DB_NAME}" \
  --dbuser="${DB_USER}" \
  --dbpass="${DB_PASS}" \
  --locale=de_DE \
  --allow-root

echo "🚀 Installiere WordPress-Core..."
wp core install \
  --url="http://${FQDN}" \
  --title="${SUB} - S Neue Website" \
  --admin_user="we-admin" \
  --admin_password="We-25-\$\$-Vo" \
  --admin_email="admin@online-aesthetik.de" \
  --skip-email \
  --allow-root

echo "✅ WordPress für ${SUB} erfolgreich installiert."
echo "🔗 URL: http://${FQDN}"
echo "👤 Admin: we-admin / We-25-\$\$-Vo"
EOF
chmod +x /opt/infra-scripts/wordpress/install_wp.sh

# 3. Create a manual DNS testing tool
echo "🔧 Creating DNS test tool..."
cat > /opt/infra-scripts/dns-test.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <subdomain>"
  exit 1
fi

SUB="$1"
DOMAIN="s-neue.website"
FQDN="${SUB}.${DOMAIN}"

echo "🔍 Testing DNS for ${FQDN}"
echo ""

echo "Standard DNS lookup:"
dig +short "${FQDN}"
echo ""

echo "Cloudflare DNS lookup (1.1.1.1):"
dig +short @1.1.1.1 "${FQDN}"
echo ""

echo "Google DNS lookup (8.8.8.8):"
dig +short @8.8.8.8 "${FQDN}"
echo ""

echo "Checking Cloudflare API:"
curl -s "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=A&name=${FQDN}" \
     -H "Authorization: Bearer ${CF_API_TOKEN}" | grep "name" || echo "No record found in API"
echo ""

echo "✅ DNS test complete."
EOF
chmod +x /opt/infra-scripts/dns-test.sh
ln -sf /opt/infra-scripts/dns-test.sh /usr/local/bin/dns-test

# 4. Create a force install script that bypasses DNS checks
echo "🔧 Creating force install script..."
cat > /opt/infra-scripts/force-install-wp.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <subdomain>"
  exit 1
fi

SUB="$1"
INFRA_DIR="/opt/infra-scripts"

echo "🛠️ Force-installing WordPress for ${SUB}..."
echo "⚠️ This will bypass all DNS checks!"

# Run install_wp.sh with TEST_MODE=true to bypass DNS checks
export TEST_MODE=true
bash "${INFRA_DIR}/wordpress/install_wp.sh" "${SUB}"

echo "✅ Force installation complete for ${SUB}."
EOF
chmod +x /opt/infra-scripts/force-install-wp.sh
ln -sf /opt/infra-scripts/force-install-wp.sh /usr/local/bin/force-install-wp

echo "✅ All DNS fixes applied!"
echo ""
echo "You now have three options to install WordPress:"
echo ""
echo "1. Regular installation (with improved DNS checks):"
echo "   setup_wp testkunde4"
echo ""
echo "2. Test DNS resolution for a subdomain:"
echo "   dns-test testkunde3"
echo ""
echo "3. Force install (bypass DNS checks completely):"
echo "   force-install-wp testkunde3"
echo ""
echo "Try option 2 first to see if your DNS is working, then try option 3"
echo "if you want to proceed regardless of DNS status."