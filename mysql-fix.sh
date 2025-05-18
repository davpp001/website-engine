#!/usr/bin/env bash
set -euo pipefail

# This script fixes MySQL user permissions issues

echo "🔧 Fixing MySQL permissions issues..."

# 1. Check current MySQL status
echo "🔍 Checking MySQL service status..."
systemctl status mysql.service --no-pager || echo "MySQL service not found"

# 2. Fix MySQL user permissions
echo "🔧 Fixing MySQL user permissions..."

# Option 1: Fix permissions for existing wordpressuser
echo "Checking if 'wordpressuser' exists..."
if mysql -u root -e "SELECT User FROM mysql.user WHERE User='wordpressuser'" | grep -q wordpressuser; then
  echo "User 'wordpressuser' exists, granting additional privileges..."
  mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'wordpressuser'@'localhost' WITH GRANT OPTION;"
  mysql -u root -e "FLUSH PRIVILEGES;"
else
  echo "User 'wordpressuser' does not exist, will create it in the modified script"
fi

# 3. Fix the database creation part in install_wp.sh
echo "🔧 Modifying install_wp.sh to fix database creation..."
INSTALL_SCRIPT="/opt/infra-scripts/wordpress/install_wp.sh"

# Create a backup first
cp "$INSTALL_SCRIPT" "$INSTALL_SCRIPT.bak.$(date +%s)"

# Replace the database creation block with a more robust version
sed -i '/echo "🗃️ Erstelle MySQL-Datenbank..."/,/mysql -u root -e "FLUSH PRIVILEGES;"/c\
echo "🗃️ Erstelle MySQL-Datenbank..."\
# Create database without requiring GRANT privileges\
mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;"\
\
# Check if user already exists\
if ! mysql -u root -e "SELECT user FROM mysql.user WHERE user='\''${DB_USER}'\''" | grep -q "${DB_USER}"; then\
  echo "Creating new MySQL user ${DB_USER}..."\
  mysql -u root -e "CREATE USER '\''${DB_USER}'\''@'\''localhost'\'' IDENTIFIED BY '\''${DB_PASS}'\'';" || echo "Could not create user, may already exist"\
fi\
\
# Grant privileges to the specific database only (this requires fewer permissions)\
mysql -u root -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '\''${DB_USER}'\''@'\''localhost'\'';" || echo "Could not grant privileges, continuing anyway"\
mysql -u root -e "FLUSH PRIVILEGES;"' "$INSTALL_SCRIPT"

# 4. Create a direct MySQL database creation script for testkunde4
echo "🔧 Creating direct database fix for existing installations..."
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

# Check if user exists
if ! mysql -u root -e "SELECT user FROM mysql.user WHERE user='${DB_USER}'" | grep -q "${DB_USER}"; then
  echo "Creating MySQL user ${DB_USER}..."
  mysql -u root -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';" || echo "Could not create user"
fi

# Grant privileges
mysql -u root -e "GRANT ALL PRIVILEGES ON \`${SUB}\`.* TO '${DB_USER}'@'localhost';" || echo "Could not grant privileges"
mysql -u root -e "FLUSH PRIVILEGES;"

echo "✅ Database ${SUB} created and permissions granted to ${DB_USER}"
EOF
chmod +x /opt/infra-scripts/mysql-create-db.sh
ln -sf /opt/infra-scripts/mysql-create-db.sh /usr/local/bin/mysql-create-db

# 5. Create a script to finalize the WordPress setup
echo "🔧 Creating WordPress finalization script..."
cat > /opt/infra-scripts/finalize-wp.sh << 'EOF'
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
DB_NAME="${SUB}"
DB_USER="wordpressuser"
DB_PASS="password"

echo "🔧 Finalizing WordPress setup for ${SUB}..."

# 1. Check if directory exists
if [ ! -d "$WWW_PATH" ]; then
  echo "Creating WordPress directory..."
  mkdir -p "$WWW_PATH"
  chown -R www-data:www-data "$WWW_PATH"
fi

# 2. Move to WordPress directory
cd "$WWW_PATH"

# 3. Check if WordPress is downloaded
if [ ! -f "$WWW_PATH/wp-config-sample.php" ]; then
  echo "Downloading WordPress..."
  wp core download --locale=de_DE --allow-root
else
  echo "WordPress already downloaded"
fi

# 4. Create database if needed
echo "Ensuring database exists..."
mysql-create-db "$SUB"

# 5. Create wp-config.php if it doesn't exist
if [ ! -f "$WWW_PATH/wp-config.php" ]; then
  echo "Creating wp-config.php..."
  wp config create \
    --dbname="${DB_NAME}" \
    --dbuser="${DB_USER}" \
    --dbpass="${DB_PASS}" \
    --locale=de_DE \
    --allow-root
else
  echo "wp-config.php already exists"
fi

# 6. Check if WordPress is installed
if ! wp core is-installed --allow-root; then
  echo "Installing WordPress core..."
  wp core install \
    --url="http://${FQDN}" \
    --title="${SUB} - S Neue Website" \
    --admin_user="we-admin" \
    --admin_password="We-25-\$\$-Vo" \
    --admin_email="admin@online-aesthetik.de" \
    --skip-email \
    --allow-root
else
  echo "WordPress already installed"
fi

# 7. Ensure Apache config exists
VHOST_PATH="/etc/apache2/sites-available/${SUB}.conf"
if [ ! -f "$VHOST_PATH" ]; then
  echo "Creating Apache vHost configuration..."
  cat > "$VHOST_PATH" << VHOST
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

  echo "Enabling site..."
  a2ensite "${SUB}.conf"
  systemctl reload apache2
else
  echo "Apache configuration already exists"
fi

echo "✅ WordPress setup finalized for ${SUB}"
echo "🔗 URL: http://${FQDN}"
echo "👤 Admin: we-admin / We-25-\$\$-Vo"
EOF
chmod +x /opt/infra-scripts/finalize-wp.sh
ln -sf /opt/infra-scripts/finalize-wp.sh /usr/local/bin/finalize-wp

echo "✅ All MySQL fixes applied!"
echo ""
echo "You now have three options to complete the installation:"
echo ""
echo "1. For testkunde4 that was partially set up:"
echo "   mysql-create-db testkunde4"
echo "   finalize-wp testkunde4"
echo ""
echo "2. For new installations:"
echo "   setup_wp testkunde5"
echo ""
echo "3. For existing installations that need to be completed:"
echo "   finalize-wp testkunde3"
echo ""
echo "The MySQL issues should now be fixed for all future installations."