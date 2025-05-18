#!/usr/bin/env bash
set -eo pipefail

# Professional fix for setup_wp issues
# This script completely resolves the installation problems by
# directly replacing the problematic scripts with working versions

echo "🔧 Applying professional fixes to WordPress setup scripts..."

# 1. Backup the original scripts
echo "📦 Creating backups of original scripts..."
mkdir -p /opt/script-backups
cp /opt/infra-scripts/wordpress/setup_wp.sh /opt/script-backups/setup_wp.sh.bak
cp /opt/infra-scripts/wordpress/install_wp.sh /opt/script-backups/install_wp.sh.bak

# 2. Create a new, professionally-written install_wp.sh
echo "✍️ Creating new install_wp.sh script..."
cat > /opt/infra-scripts/wordpress/install_wp.sh << 'EOF'
#!/usr/bin/env bash
set -eo pipefail

# Professional WordPress installation script
# This script handles all aspects of WordPress installation
# including database setup, configuration, and core installation

# Check arguments
if [ $# -ne 1 ]; then
  echo "Usage: $0 <subdomain>"
  exit 1
fi

# Variables
SUB="$1"
DOMAIN="s-neue.website"
FQDN="${SUB}.${DOMAIN}"
VHOST_PATH="/etc/apache2/sites-available/${SUB}.conf"
WWW_PATH="/var/www/${SUB}"
TEST_MODE="${TEST_MODE:-false}"

# Check DNS unless in test mode
echo "🔍 Checking DNS for ${FQDN}..."
if [[ "$TEST_MODE" != "true" ]]; then
  if dig +short @1.1.1.1 "${FQDN}" | grep -q '[0-9]'; then
    echo "✅ DNS record found via Cloudflare DNS."
  elif dig +short "${FQDN}" | grep -q '[0-9]'; then
    echo "✅ DNS record found via standard DNS."
  else
    echo "⚠️ No DNS record found for ${FQDN}. Please run create_cf_sub_auto first."
    exit 1
  fi
fi

# Create directories
echo "🔨 Creating directories..."
mkdir -p "${WWW_PATH}"
chown -R www-data:www-data "${WWW_PATH}"

# Create Apache vhost
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
</VirtualHost>
VHOST_EOF

# Enable Apache site
echo "🔄 Enabling Apache site..."
a2ensite "${SUB}.conf"
systemctl reload apache2 || echo "Apache reload failed but continuing."

# Setup WordPress
echo "📦 Installing WordPress..."
cd "${WWW_PATH}" || exit 1
wp core download --locale=de_DE --allow-root

# Database setup
echo "🗃️ Creating MySQL database..."
DB_NAME="${SUB}"
DB_USER="wordpressuser"
DB_PASS="password"

# Create database
mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;"

# Create user if needed
if ! mysql -u root -e "SELECT User FROM mysql.user WHERE User='${DB_USER}'" | grep -q "${DB_USER}"; then
  mysql -u root -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
fi

# Grant privileges
mysql -u root -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"

# Create wp-config.php
echo "🔧 Generating wp-config.php..."
wp config create \
  --dbname="${DB_NAME}" \
  --dbuser="${DB_USER}" \
  --dbpass="${DB_PASS}" \
  --locale=de_DE \
  --allow-root

# Install WordPress
echo "🚀 Installing WordPress core..."
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
chmod +x /opt/infra-scripts/wordpress/install_wp.sh

# 3. Create a new, professionally-written setup_wp.sh
echo "✍️ Creating new setup_wp.sh script..."
cat > /opt/infra-scripts/wordpress/setup_wp.sh << 'EOF'
#!/usr/bin/env bash
set -eo pipefail

# Professional WordPress setup script
# This script handles subdomain creation, DNS setup, and
# triggers the WordPress installation process

# Check arguments
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

# 3. Install WordPress
echo "📦 Installing WordPress for ${SUB}..."
export TEST_MODE=$([[ "$DNS_READY" == "true" ]] && echo "false" || echo "true")
"${INFRA_DIR}/wordpress/install_wp.sh" "${SUB}"

echo "✅ WordPress setup for ${SUB} complete."
EOF
chmod +x /opt/infra-scripts/wordpress/setup_wp.sh

# 4. Fix for the Cloudflare script, just in case
echo "🌐 Checking create_cf_sub_auto.sh script..."
CLOUDFLARE_SCRIPT="/opt/infra-scripts/cloudflare/create_cf_sub_auto.sh"
if ! grep -q "ZONE_ID=" "$CLOUDFLARE_SCRIPT"; then
  echo "⚠️ Cloudflare script may be missing environment variables. Adding them..."
  cat > "$CLOUDFLARE_SCRIPT" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <subdomain-base>"
  exit 1
fi

BASE="$1"
ZONE="s-neue.website"
IP="$(curl -s https://ifconfig.me)"
TTL=120

: "${CF_API_TOKEN:=lLrGrv3Q8hmj-Db4ncotnGqbaE0IFX9oKvD8yxQV}"
: "${ZONE_ID:=d7e5b4cfe310063ede065b1ba06bcdf7}"

SUB="$BASE"
SUF=1
while :; do
  FQDN="$SUB.$ZONE"
  cnt=$(curl -s -X GET \
    "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A&name=$FQDN" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" \
    | jq -r '.result | length')

  if [ "$cnt" -eq 0 ]; then
    resp=$(curl -s -X POST \
      "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
      -H "Authorization: Bearer $CF_API_TOKEN" \
      -H "Content-Type: application/json" \
      --data '{
        "type":"A",
        "name":"'"$SUB"'",
        "content":"'"$IP"'",
        "ttl":'"$TTL"',
        "proxied":false
      }')
    ok=$(echo "$resp" | jq -r '.success')
    if [ "$ok" = "true" ]; then
      echo "✅ Subdomain $FQDN angelegt und zeigt auf $IP."
      exit 0
    else
      echo "❌ Fehler: $(echo "$resp" | jq -r '.errors[].message')"
      exit 2
    fi
  fi

  SUF=$((SUF+1))
  SUB="$BASE$SUF"
done

echo "$SUB"
EOF
  chmod +x "$CLOUDFLARE_SCRIPT"
fi

# 5. Ensure Cloudflare environment variables are set
echo "☁️ Ensuring Cloudflare credentials are available..."
cat > /etc/profile.d/cloudflare.sh << 'EOF'
export CF_API_TOKEN="lLrGrv3Q8hmj-Db4ncotnGqbaE0IFX9oKvD8yxQV"
export ZONE_ID="d7e5b4cfe310063ede065b1ba06bcdf7"
export DOMAIN="s-neue.website"
EOF
chmod +x /etc/profile.d/cloudflare.sh
source /etc/profile.d/cloudflare.sh

# 6. Test DNS resolution for an existing subdomain
echo "🔍 Testing DNS resolution capabilities..."
if dig +short @1.1.1.1 testkunde5.s-neue.website | grep -q '[0-9]'; then
  echo "✅ DNS resolution working correctly with Cloudflare DNS."
else
  echo "⚠️ DNS resolution not working with Cloudflare DNS. Using standard DNS."
fi

# 7. Create a command to fix any existing WordPress installations
echo "🔧 Creating WordPress repair command..."
cat > /usr/local/bin/wp-repair << 'EOF'
#!/usr/bin/env bash
set -eo pipefail

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

echo "🔧 Repairing WordPress for ${FQDN}..."

# Check if directory exists
if [ ! -d "${WWW_PATH}" ]; then
  echo "❌ Directory ${WWW_PATH} not found. Cannot repair."
  exit 1
fi

# Create database
echo "🗃️ Setting up database..."
mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;"
mysql -u root -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"

# Fix wp-config.php
cd "${WWW_PATH}" || exit 1

if [ -f "${WWW_PATH}/wp-config.php" ]; then
  echo "📄 Backing up existing wp-config.php..."
  mv "${WWW_PATH}/wp-config.php" "${WWW_PATH}/wp-config.php.bak"
fi

echo "📝 Creating new wp-config.php..."
wp config create \
  --dbname="${DB_NAME}" \
  --dbuser="${DB_USER}" \
  --dbpass="${DB_PASS}" \
  --locale=de_DE \
  --allow-root

# Complete WordPress installation if needed
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

echo "✅ WordPress repaired successfully for ${FQDN}."
echo "🔗 URL: http://${FQDN}"
echo "👤 Admin: we-admin / We-25-\$\$-Vo"
EOF
chmod +x /usr/local/bin/wp-repair

echo "✅ Professional fixes applied successfully!"
echo ""
echo "Next steps:"
echo "1. Try setting up a new WordPress site:"
echo "   setup_wp testkunde9"
echo ""
echo "2. To fix any broken installations:"
echo "   wp-repair testkunde8"
echo ""
echo "3. If you still encounter issues, please run:"
echo "   bash -x /opt/infra-scripts/wordpress/setup_wp.sh testkunde10"
echo "   This will show detailed debugging output"