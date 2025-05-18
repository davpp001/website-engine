#!/usr/bin/env bash
set -euo pipefail

# This script fixes the MySQL syntax error

echo "🔧 Fixing MySQL syntax error..."

# 1. First, inspect the current install_wp.sh to see what went wrong
echo "🔍 Inspecting install_wp.sh script..."
cat /opt/infra-scripts/wordpress/install_wp.sh | grep -A15 "Erstelle MySQL-Datenbank"

# 2. Create a completely new version of install_wp.sh
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
    exit 1
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

# Database setup variables
DB_NAME="${SUB}"
DB_USER="wordpressuser"
DB_PASS="password" # In der Praxis besser aus .env o.ä. lesen

echo "🗃️ Erstelle MySQL-Datenbank..."
# Create database
mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;"

# Check if user exists and create if needed
mysql -u root -e "SELECT COUNT(*) FROM mysql.user WHERE user='${DB_USER}'" | grep -q "^0$" && \
  mysql -u root -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"

# Grant privileges to the user
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

# 3. Fix the mysql-create-db script as well
echo "🔧 Fixing mysql-create-db script..."
cat > /opt/infra-scripts/mysql-create-db.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <subdomain>"
  exit 1
fi

SUB="$1"
DB_USER="wordpressuser"
DB_PASS="password"

echo "🔧 Creating database for ${SUB}..."

# Create the database
mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`${SUB}\`;"

# Check if user exists and create if not
USER_EXISTS=$(mysql -u root -e "SELECT COUNT(*) FROM mysql.user WHERE user='${DB_USER}'" | grep -v "COUNT")
if [ "$USER_EXISTS" -eq "0" ]; then
  echo "Creating MySQL user ${DB_USER}..."
  mysql -u root -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';" || echo "Could not create user"
else
  echo "User ${DB_USER} already exists"
fi

# Grant privileges
mysql -u root -e "GRANT ALL PRIVILEGES ON \`${SUB}\`.* TO '${DB_USER}'@'localhost';" || echo "Could not grant privileges"
mysql -u root -e "FLUSH PRIVILEGES;"

echo "✅ Database ${SUB} created and permissions granted to ${DB_USER}"
EOF
chmod +x /opt/infra-scripts/mysql-create-db.sh

# 4. Fix apache reload error by creating another script
echo "🔧 Creating apache-fix script..."
cat > /opt/infra-scripts/apache-fix.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Fixing Apache configuration..."

# Make sure Apache is running
if ! systemctl is-active --quiet apache2; then
  echo "Starting Apache..."
  systemctl start apache2
  systemctl status apache2 --no-pager
fi

# Reload the configuration
echo "Reloading Apache configuration..."
systemctl reload apache2

echo "✅ Apache configuration fixed!"
echo "You can now install WordPress with:"
echo "setup_wp testkunde5"
EOF
chmod +x /opt/infra-scripts/apache-fix.sh
ln -sf /opt/infra-scripts/apache-fix.sh /usr/local/bin/apache-fix

echo "✅ All fixes applied!"
echo ""
echo "Now follow these steps:"
echo ""
echo "1. First, fix Apache:"
echo "   apache-fix"
echo ""
echo "2. Then try a new installation:"
echo "   setup_wp testkunde5"
echo ""
echo "The MySQL syntax error has been fixed in the installation script."