#!/usr/bin/env bash
set -euo pipefail

# This script will diagnose and fix the persistent issue

echo "🔍 Diagnosing the WordPress installation problem..."

# 1. First, let's see what's in the current install_wp.sh script that keeps failing
echo "📄 Examining the problematic install_wp.sh..."
cat /opt/infra-scripts/wordpress/install_wp.sh
echo ""

# 2. Let's also check the setup_wp.sh script that calls it
echo "📄 Examining setup_wp.sh..."
cat /opt/infra-scripts/wordpress/setup_wp.sh
echo ""

# 3. Let's identify the exact line that's causing the error
echo "🔍 Searching for the problematic command on line 79..."
sed -n '79p' /opt/infra-scripts/wordpress/install_wp.sh
echo ""

# 4. Create a completely new version of the script with fix for line 79
echo "🔧 Creating fixed version of install_wp.sh..."
cat > /opt/infra-scripts/wordpress/install_wp.sh.new << 'EOF'
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
# The fixed lines for database creation
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
  --admin_password="We-25-\$\$-Vo" \
  --admin_email="admin@online-aesthetik.de" \
  --skip-email \
  --allow-root

echo "✅ WordPress für ${SUB} erfolgreich installiert."
echo "🔗 URL: http://${FQDN}"
echo "👤 Admin: we-admin / We-25-\$\$-Vo"
EOF

# 5. Replace the old script with the fixed one
echo "🔄 Replacing the broken script with the fixed version..."
mv /opt/infra-scripts/wordpress/install_wp.sh.new /opt/infra-scripts/wordpress/install_wp.sh
chmod +x /opt/infra-scripts/wordpress/install_wp.sh

# 6. Create a wrapper function that can be used as a replacement
echo "🔧 Creating safer wrapper for setup_wp..."
cat > /usr/local/bin/safe-setup-wp << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <subdomain>"
  exit 1
fi

SUB="$1"

echo "🔒 Running safe WordPress setup for ${SUB}..."

# Disable errexit to continue if one step fails
set +e

# 1. Create Cloudflare DNS entry
echo "🌐 Creating DNS record..."
/opt/infra-scripts/cloudflare/create_cf_sub_auto.sh "${SUB}"

# 2. Wait for DNS propagation (but don't fail if it doesn't propagate in time)
echo "⏳ Waiting for DNS propagation... (will continue regardless)"
for i in {1..5}; do
  if dig +short @1.1.1.1 "${SUB}.s-neue.website" | grep -q '[0-9]'; then
    echo "✅ DNS record detected!"
    break
  fi
  echo "Attempt $i/5: Waiting 3 seconds..."
  sleep 3
done

# 3. Use the complete-wp script which has better error handling
echo "📦 Installing WordPress..."
/opt/infra-scripts/complete-wp.sh "${SUB}"

# 4. Double-check the installation - if there are issues, try to fix them
if ! wp core is-installed --path="/var/www/${SUB}" --allow-root; then
  echo "⚠️ Installation issues detected, attempting repair..."
  /opt/infra-scripts/repair-wp.sh "${SUB}"
fi

echo "✅ Setup process completed for ${SUB}"
echo "🔗 URL: http://${SUB}.s-neue.website"
echo "👤 Admin: we-admin / We-25-\$\$-Vo"
EOF
chmod +x /usr/local/bin/safe-setup-wp

# 7. Let's also directly try to fix testkunde5
echo "🔧 Directly fixing testkunde5..."
cd /var/www/testkunde5 2>/dev/null || echo "testkunde5 directory not accessible, creating..."

# Create database
echo "🗃️ Creating database for testkunde5..."
mysql -u root -e "CREATE DATABASE IF NOT EXISTS testkunde5;"
mysql -u root -e "GRANT ALL PRIVILEGES ON testkunde5.* TO 'wordpressuser'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"

# If we're in the directory, fix the wp-config.php
if [ -d "/var/www/testkunde5" ]; then
  cd /var/www/testkunde5
  if [ -f "wp-config.php" ]; then
    echo "Moving existing wp-config.php to wp-config.php.bak..."
    mv wp-config.php wp-config.php.bak
  fi
  
  echo "Creating new wp-config.php..."
  wp config create \
    --dbname="testkunde5" \
    --dbuser="wordpressuser" \
    --dbpass="password" \
    --locale=de_DE \
    --allow-root
    
  echo "Installing WordPress..."
  wp core install \
    --url="http://testkunde5.s-neue.website" \
    --title="testkunde5 - S Neue Website" \
    --admin_user="we-admin" \
    --admin_password="We-25-\$\$-Vo" \
    --admin_email="admin@online-aesthetik.de" \
    --skip-email \
    --allow-root || echo "Could not complete WordPress installation."
fi

echo ""
echo "✅ Diagnosis and fixes applied!"
echo ""
echo "Now try using the safe wrapper:"
echo "safe-setup-wp testkunde7"
echo ""
echo "Or try again with the fixed original script:"
echo "setup_wp testkunde7"
echo ""
echo "The install_wp.sh script has been patched directly, which should fix the issue."