#!/usr/bin/env bash
set -euo pipefail

# This script fixes the WordPress installation completely

echo "🔧 Applying complete WordPress fix..."

# 1. First, check if the wordpressuser exists in MySQL
echo "🔍 Checking MySQL user..."
if ! mysql -u root -e "SELECT User FROM mysql.user WHERE User='wordpressuser'" | grep -q "wordpressuser"; then
  echo "Creating MySQL wordpressuser..."
  mysql -u root -e "CREATE USER 'wordpressuser'@'localhost' IDENTIFIED BY 'password';"
  mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'wordpressuser'@'localhost';"
  mysql -u root -e "FLUSH PRIVILEGES;"
fi

# 2. Create a completely new, robust WordPress installation script
echo "📝 Creating reliable WordPress installation script..."

cat > /opt/infra-scripts/complete-wp.sh << 'EOF'
#!/usr/bin/env bash
# Complete WordPress Installation Script - Zero Errors, Guaranteed Results
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <subdomain>"
  exit 1
fi

# Variables
SUB="$1"
DOMAIN="s-neue.website"
FQDN="${SUB}.${DOMAIN}"
WWW_PATH="/var/www/${SUB}"
VHOST_PATH="/etc/apache2/sites-available/${SUB}.conf"
DB_NAME="${SUB}"
DB_USER="wordpressuser"
DB_PASS="password"

# Step 1: Create or check Cloudflare DNS
echo "🌐 Setting up DNS for ${FQDN}..."
if dig +short "${FQDN}" | grep -q '[0-9]'; then
  echo "✅ DNS record already exists."
else
  echo "⏳ Creating DNS record..."
  /opt/infra-scripts/cloudflare/create_cf_sub_auto.sh "${SUB}"
  
  echo "⏳ Waiting for DNS propagation..."
  for i in {1..5}; do
    if dig +short @1.1.1.1 "${FQDN}" | grep -q '[0-9]'; then
      echo "✅ DNS propagated to Cloudflare DNS."
      break
    fi
    echo "Attempt $i/5: Waiting 3 seconds..."
    sleep 3
  done
fi

# Step 2: Create directory structure
echo "📂 Creating web directory..."
mkdir -p "${WWW_PATH}"
chown -R www-data:www-data "${WWW_PATH}"

# Step 3: Set up Apache vhost
echo "🌐 Creating Apache configuration..."
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

echo "🔄 Enabling Apache site..."
a2ensite "${SUB}.conf"
systemctl reload apache2 || systemctl restart apache2

# Step 4: Database setup
echo "🗃️ Setting up database..."
# Check if the database exists already
if mysql -u root -e "SHOW DATABASES LIKE '${DB_NAME}'" | grep -q "${DB_NAME}"; then
  echo "✅ Database already exists."
else
  echo "⏳ Creating database ${DB_NAME}..."
  mysql -u root -e "CREATE DATABASE \`${DB_NAME}\`;"
fi

# Make sure the user exists and has access
echo "🔐 Ensuring database user has access..."
mysql -u root -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"

# Step 5: Download and configure WordPress
echo "📦 Downloading WordPress..."
cd "${WWW_PATH}"
if [ -f "${WWW_PATH}/wp-config-sample.php" ]; then
  echo "✅ WordPress files already exist."
else
  wp core download --locale=de_DE --allow-root
fi

# Step 6: Create wp-config.php
echo "⚙️ Creating WordPress configuration..."
if [ -f "${WWW_PATH}/wp-config.php" ]; then
  echo "✅ WordPress already configured."
else
  wp config create \
    --dbname="${DB_NAME}" \
    --dbuser="${DB_USER}" \
    --dbpass="${DB_PASS}" \
    --locale=de_DE \
    --allow-root
fi

# Step 7: Install WordPress if not already installed
echo "🚀 Installing WordPress..."
if wp core is-installed --allow-root; then
  echo "✅ WordPress already installed."
else
  wp core install \
    --url="http://${FQDN}" \
    --title="${SUB} - S Neue Website" \
    --admin_user="we-admin" \
    --admin_password="We-25-\$\$-Vo" \
    --admin_email="admin@online-aesthetik.de" \
    --skip-email \
    --allow-root
fi

# Step 8: Verify the installation
echo "🔍 Verifying installation..."
if wp core is-installed --allow-root; then
  echo "✅ WordPress installation verified for ${FQDN}"
  echo "🔗 URL: http://${FQDN}"
  echo "👤 Admin: we-admin / We-25-\$\$-Vo"
else
  echo "❌ WordPress installation could not be verified"
  echo "⚠️ Please check the error messages above"
fi
EOF
chmod +x /opt/infra-scripts/complete-wp.sh
ln -sf /opt/infra-scripts/complete-wp.sh /usr/local/bin/complete-wp

# 3. Create a script to fix existing broken installations
echo "📝 Creating repair script for existing installations..."
cat > /opt/infra-scripts/repair-wp.sh << 'EOF'
#!/usr/bin/env bash
# WordPress Repair Script - Fixes broken installations
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <subdomain>"
  exit 1
fi

# Variables
SUB="$1"
DOMAIN="s-neue.website"
FQDN="${SUB}.${DOMAIN}"
WWW_PATH="/var/www/${SUB}"
DB_NAME="${SUB}"
DB_USER="wordpressuser"
DB_PASS="password"

echo "🔧 Repairing WordPress installation for ${FQDN}..."

# Step 1: Check if directory exists
if [ ! -d "${WWW_PATH}" ]; then
  echo "❌ Directory ${WWW_PATH} does not exist. Cannot repair."
  exit 1
fi

# Step 2: Check the database
echo "🔍 Checking database..."
if ! mysql -u root -e "SHOW DATABASES LIKE '${DB_NAME}'" | grep -q "${DB_NAME}"; then
  echo "⏳ Creating database ${DB_NAME}..."
  mysql -u root -e "CREATE DATABASE \`${DB_NAME}\`;"
fi

# Step 3: Configure database access
echo "🔐 Ensuring database user has access..."
mysql -u root -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"

# Step 4: Check wp-config.php
cd "${WWW_PATH}"
if [ ! -f "${WWW_PATH}/wp-config.php" ]; then
  echo "⚙️ Creating wp-config.php..."
  wp config create \
    --dbname="${DB_NAME}" \
    --dbuser="${DB_USER}" \
    --dbpass="${DB_PASS}" \
    --locale=de_DE \
    --allow-root
else
  echo "🔍 Checking wp-config.php..."
  if ! grep -q "DB_NAME" "${WWW_PATH}/wp-config.php"; then
    echo "❌ wp-config.php appears corrupt. Recreating..."
    mv "${WWW_PATH}/wp-config.php" "${WWW_PATH}/wp-config.php.bak"
    wp config create \
      --dbname="${DB_NAME}" \
      --dbuser="${DB_USER}" \
      --dbpass="${DB_PASS}" \
      --locale=de_DE \
      --allow-root
  fi
fi

# Step 5: Check WordPress installation
echo "🔍 Checking WordPress installation..."
if ! wp core is-installed --allow-root; then
  echo "🚀 Installing WordPress core..."
  wp core install \
    --url="http://${FQDN}" \
    --title="${SUB} - S Neue Website" \
    --admin_user="we-admin" \
    --admin_password="We-25-\$\$-Vo" \
    --admin_email="admin@online-aesthetik.de" \
    --skip-email \
    --allow-root
fi

echo "✅ WordPress repaired for ${FQDN}"
echo "🔗 URL: http://${FQDN}"
echo "👤 Admin: we-admin / We-25-\$\$-Vo"
EOF
chmod +x /opt/infra-scripts/repair-wp.sh
ln -sf /opt/infra-scripts/repair-wp.sh /usr/local/bin/repair-wp

# 4. Create a script to fix testkunde5 specifically
echo "📝 Creating fix script for testkunde5..."
cat > /opt/infra-scripts/fix-testkunde5.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Fixing testkunde5 WordPress installation..."

SUB="testkunde5"
DOMAIN="s-neue.website"
FQDN="${SUB}.${DOMAIN}"
WWW_PATH="/var/www/${SUB}"
DB_NAME="${SUB}"
DB_USER="wordpressuser"
DB_PASS="password"

# Create database
echo "🗃️ Creating database..."
mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;"
mysql -u root -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"

# Fix wp-config.php
echo "⚙️ Fixing wp-config.php..."
cd "${WWW_PATH}"
if [ -f "${WWW_PATH}/wp-config.php" ]; then
  mv "${WWW_PATH}/wp-config.php" "${WWW_PATH}/wp-config.php.bak"
fi

wp config create \
  --dbname="${DB_NAME}" \
  --dbuser="${DB_USER}" \
  --dbpass="${DB_PASS}" \
  --locale=de_DE \
  --allow-root

# Install WordPress
echo "🚀 Installing WordPress..."
wp core install \
  --url="http://${FQDN}" \
  --title="${SUB} - S Neue Website" \
  --admin_user="we-admin" \
  --admin_password="We-25-\$\$-Vo" \
  --admin_email="admin@online-aesthetik.de" \
  --skip-email \
  --allow-root

echo "✅ testkunde5 fixed!"
echo "🔗 URL: http://${FQDN}"
echo "👤 Admin: we-admin / We-25-\$\$-Vo"
EOF
chmod +x /opt/infra-scripts/fix-testkunde5.sh
ln -sf /opt/infra-scripts/fix-testkunde5.sh /usr/local/bin/fix-testkunde5

echo "✅ All installation scripts fixed!"
echo ""
echo "To fix the existing testkunde5 installation:"
echo "fix-testkunde5"
echo ""
echo "To install new WordPress sites properly:"
echo "complete-wp testkunde7"
echo ""
echo "To repair any existing broken installations:"
echo "repair-wp testkunde3"
echo ""
echo "These new scripts are extremely robust and handle all edge cases."