#!/usr/bin/env bash
set -euo pipefail

# This script provides a direct, simple fix for the installation issue

echo "🔧 Applying simple, direct fix..."

# 1. Create a completely new WordPress installation script
echo "📝 Creating fixed installation script..."

cat > /opt/infra-scripts/direct-install-wp.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <subdomain>"
  exit 1
fi

SUB="$1"
DOMAIN="s-neue.website"
FQDN="${SUB}.${DOMAIN}"
WWW_PATH="/var/www/${SUB}"
VHOST_PATH="/etc/apache2/sites-available/${SUB}.conf"

echo "🚀 Direct WordPress installation for ${SUB}"

# 1. Create directories
echo "📁 Creating directories..."
mkdir -p "${WWW_PATH}"
chown -R www-data:www-data "${WWW_PATH}"

# 2. Create Apache vhost
echo "🌐 Creating Apache vhost..."
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

echo "🔄 Enabling site and reloading Apache..."
a2ensite "${SUB}.conf"
systemctl reload apache2 || echo "Apache reload failed, but continuing anyway"

# 3. Set up database
echo "💾 Creating database..."
DB_NAME="${SUB}"
DB_USER="wordpressuser"
DB_PASS="password"

# Create database
mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;"

# Create user if it doesn't exist
if ! mysql -u root -e "SELECT User FROM mysql.user WHERE User='${DB_USER}'" | grep -q "${DB_USER}"; then
  echo "Creating database user..."
  mysql -u root -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
fi

# Grant privileges
mysql -u root -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"

# 4. Download and install WordPress
echo "📦 Downloading WordPress..."
cd "${WWW_PATH}"
wp core download --locale=de_DE --allow-root

echo "⚙️ Configuring WordPress..."
wp config create \
  --dbname="${DB_NAME}" \
  --dbuser="${DB_USER}" \
  --dbpass="${DB_PASS}" \
  --locale=de_DE \
  --allow-root

echo "✅ Installing WordPress core..."
wp core install \
  --url="http://${FQDN}" \
  --title="${SUB} - S Neue Website" \
  --admin_user="we-admin" \
  --admin_password="We-25-\$\$-Vo" \
  --admin_email="admin@online-aesthetik.de" \
  --skip-email \
  --allow-root

echo "✅ WordPress successfully installed for ${SUB}"
echo "🔗 URL: http://${FQDN}"
echo "👤 Admin: we-admin / We-25-\$\$-Vo"
EOF
chmod +x /opt/infra-scripts/direct-install-wp.sh
ln -sf /opt/infra-scripts/direct-install-wp.sh /usr/local/bin/direct-install-wp

# 2. Create a simple repair script for Apache
echo "📝 Creating Apache repair script..."
cat > /opt/infra-scripts/repair-apache.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Repairing Apache..."

# Start Apache if not running
if ! systemctl is-active --quiet apache2; then
  echo "Starting Apache..."
  systemctl start apache2
fi

# Reload configuration
echo "Reloading Apache configuration..."
systemctl reload apache2

echo "✅ Apache repaired."
EOF
chmod +x /opt/infra-scripts/repair-apache.sh
ln -sf /opt/infra-scripts/repair-apache.sh /usr/local/bin/repair-apache

echo "✅ Simple fix complete!"
echo ""
echo "To proceed, run these commands:"
echo ""
echo "1. Repair Apache:"
echo "   repair-apache"
echo ""
echo "2. Install WordPress directly:"
echo "   direct-install-wp testkunde5"
echo ""
echo "This direct approach bypasses any issues with the original scripts."