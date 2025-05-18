#!/usr/bin/env bash
set -euo pipefail

# WordPress Permissions Fix
# This script fixes file permissions for WordPress so that plugins can be installed
# without FTP credentials

echo "🔧 Fixing WordPress permissions..."

# 1. Update the setup_wp script to set proper permissions
echo "📝 Updating setup_wp to set correct file permissions..."
cat > /opt/infra-scripts/wordpress/setup_wp.sh << 'EOF'
#!/usr/bin/env bash
set -eo pipefail

# WordPress setup script with SSL support and proper permissions
# This script creates a subdomain, sets up WordPress, and configures SSL

if [ $# -ne 1 ]; then
  echo "Usage: $0 <subdomain>"
  exit 1
fi

# Variables
BASE="$1"
INFRA_DIR="/opt/infra-scripts"
DOMAIN="s-neue.website"

# 1. Create subdomain in Cloudflare
echo "🌐 Creating subdomain ${BASE}..."
CF_OUTPUT=$("${INFRA_DIR}/cloudflare/create_cf_sub_auto.sh" "${BASE}")
echo "${CF_OUTPUT}"

# Extract subdomain from output
SUB=$(echo "${CF_OUTPUT}" | grep -o "[a-zA-Z0-9-]*" | grep "${BASE}" | head -1 || echo "${BASE}")
FQDN="${SUB}.${DOMAIN}"

# 2. Wait for DNS propagation
echo "⏳ Waiting for DNS propagation for ${FQDN}..."
SERVER_IP=$(curl -s https://ifconfig.me)
DNS_READY=false

for i in {1..10}; do
  if dig +short @1.1.1.1 "${FQDN}" | grep -q "${SERVER_IP}"; then
    echo "✅ DNS propagated to Cloudflare DNS."
    DNS_READY=true
    break
  fi
  
  if dig +short "${FQDN}" | grep -q "${SERVER_IP}"; then
    echo "✅ DNS propagated to standard DNS."
    DNS_READY=true
    break
  fi
  
  echo "⏳ Waiting for DNS propagation... Attempt ${i}/10"
  sleep 3
done

# 3. Set up WordPress
echo "📦 Installing WordPress for ${SUB}..."

# Variables
WWW_PATH="/var/www/${SUB}"
VHOST_PATH="/etc/apache2/sites-available/${SUB}.conf"
DB_NAME="${SUB}"
DB_USER="wordpressuser"
DB_PASS="password"

# 3.1 Check DNS
echo "🔍 Checking DNS for ${FQDN}..."
if ! $DNS_READY; then
  echo "⚠️ DNS not yet propagated. Continuing anyway..."
fi

# 3.2 Create directories
echo "🔨 Creating directories..."
mkdir -p "${WWW_PATH}"
# Set proper ownership for www-data
chown -R www-data:www-data "${WWW_PATH}"

# 3.3 Create Apache vhost
echo "📝 Creating Apache vhost..."
cat > "${VHOST_PATH}" << VHOST_EOF
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
    
    RewriteEngine On
    RewriteRule ^(.*)$ https://%{HTTP_HOST}$1 [R=301,L]
</VirtualHost>
VHOST_EOF

# 3.4 Enable Apache site
echo "🔄 Enabling Apache site..."
a2ensite "${SUB}.conf"
systemctl reload apache2 || echo "Apache reload failed but continuing."

# 3.5 Set up WordPress
echo "📦 Downloading WordPress..."
cd "${WWW_PATH}" || exit 1
# Run WordPress download as www-data
sudo -u www-data wp core download --locale=de_DE --allow-root

# 3.6 Database setup
echo "🗃️ Creating MySQL database..."
# Create database
mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;"

# Check if user exists
if ! mysql -u root -e "SELECT User FROM mysql.user WHERE User='${DB_USER}'" | grep -q "${DB_USER}"; then
  echo "Creating database user..."
  mysql -u root -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
fi

# Grant privileges
mysql -u root -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"

# 3.7 Create wp-config.php
echo "🔧 Generating wp-config.php..."
# Run as www-data
sudo -u www-data wp config create \
  --dbname="${DB_NAME}" \
  --dbuser="${DB_USER}" \
  --dbpass="${DB_PASS}" \
  --locale=de_DE \
  --allow-root

# Add direct file system method to wp-config.php
echo "📝 Adding direct file system method to wp-config.php..."
sudo -u www-data wp config set FS_METHOD direct --allow-root

# 3.8 Install WordPress
echo "🚀 Installing WordPress core..."
# Run as www-data
sudo -u www-data wp core install \
  --url="https://${FQDN}" \
  --title="${SUB} - S Neue Website" \
  --admin_user="we-admin" \
  --admin_password="We-25-\$\$-Vo" \
  --admin_email="admin@online-aesthetik.de" \
  --skip-email \
  --allow-root

# 4. Set up SSL with Certbot
echo "🔒 Setting up SSL certificate..."
certbot --apache \
  --non-interactive \
  --agree-tos \
  --redirect \
  --email admin@online-aesthetik.de \
  -d "${FQDN}" || echo "⚠️ SSL setup failed, but WordPress is still installed."

# 5. Set proper permissions
echo "🔑 Setting proper file permissions..."
find "${WWW_PATH}" -type d -exec chmod 755 {} \;
find "${WWW_PATH}" -type f -exec chmod 644 {} \;
# Ensure www-data owns all files
chown -R www-data:www-data "${WWW_PATH}"
# Make wp-content writable
chmod -R 775 "${WWW_PATH}/wp-content"
# Ensure Apache can write to the directory
usermod -a -G www-data ubuntu || echo "User 'ubuntu' not found, skipping group addition"
usermod -a -G www-data root

echo "✅ WordPress setup complete for ${SUB}."
echo "🔗 URL: https://${FQDN}"
echo "👤 Admin: we-admin / We-25-\$\$-Vo"
EOF
chmod +x /opt/infra-scripts/wordpress/setup_wp.sh

# 2. Create a script to fix permissions for existing WordPress sites
echo "📝 Creating script to fix permissions for existing sites..."
cat > /opt/infra-scripts/fix-wp-permissions.sh << 'EOF'
#!/usr/bin/env bash
set -eo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <subdomain>"
  exit 1
fi

SUB="$1"
WWW_PATH="/var/www/${SUB}"

if [ ! -d "${WWW_PATH}" ]; then
  echo "❌ WordPress directory not found: ${WWW_PATH}"
  exit 1
fi

echo "🔧 Fixing permissions for ${SUB}..."

# 1. Fix file ownership
echo "👤 Setting file ownership..."
chown -R www-data:www-data "${WWW_PATH}"

# 2. Fix directory permissions
echo "📁 Setting directory permissions..."
find "${WWW_PATH}" -type d -exec chmod 755 {} \;

# 3. Fix file permissions
echo "📄 Setting file permissions..."
find "${WWW_PATH}" -type f -exec chmod 644 {} \;

# 4. Make wp-content writable
echo "✏️ Making wp-content writable..."
chmod -R 775 "${WWW_PATH}/wp-content"

# 5. Add FS_METHOD to wp-config.php
echo "⚙️ Adding FS_METHOD to wp-config.php..."
if [ -f "${WWW_PATH}/wp-config.php" ]; then
  if ! grep -q "FS_METHOD" "${WWW_PATH}/wp-config.php"; then
    sudo -u www-data wp config set FS_METHOD direct --path="${WWW_PATH}" --allow-root
  fi
fi

echo "✅ Permissions fixed for ${SUB}."
echo "You should now be able to install plugins without FTP credentials."
EOF
chmod +x /opt/infra-scripts/fix-wp-permissions.sh
ln -sf /opt/infra-scripts/fix-wp-permissions.sh /usr/local/bin/fix-wp-permissions

# 3. Fix permissions for all existing WordPress sites
echo "🔧 Fixing permissions for all existing WordPress sites..."
for SITE_DIR in /var/www/*; do
  if [ -d "${SITE_DIR}" ] && [ -f "${SITE_DIR}/wp-config.php" ]; then
    SUB=$(basename "${SITE_DIR}")
    echo "🔧 Fixing permissions for ${SUB}..."
    /opt/infra-scripts/fix-wp-permissions.sh "${SUB}"
  fi
done

# 4. Add the www-data user to relevant groups
echo "👥 Setting up proper user group memberships..."
usermod -a -G www-data ubuntu 2>/dev/null || echo "User 'ubuntu' not found, skipping group addition"
usermod -a -G www-data root

echo "✅ WordPress permissions fix complete!"
echo ""
echo "You can now install plugins without FTP credentials."
echo "If you still have issues with a specific site, run:"
echo "fix-wp-permissions sitename"
echo ""
echo "All future WordPress sites created with setup_wp will automatically have the correct permissions."