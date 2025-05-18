#!/usr/bin/env bash
set -eo pipefail

# This script fixes the setup_wp script to ensure SSL is automatically applied
# to new WordPress installations

echo "🔧 Setting up automatic SSL for new WordPress sites..."

# 1. First check if we have the wildcard certificate
echo "🔍 Checking for wildcard certificate..."
if [ ! -d "/etc/letsencrypt/live/s-neue.website" ]; then
  echo "⚠️ Wildcard certificate not found. Setting it up now..."
  
  # 1.1 Make sure Certbot is installed
  if ! command -v certbot &> /dev/null; then
    echo "📦 Installing Certbot and plugins..."
    apt-get update
    apt-get install -y certbot python3-certbot-apache python3-certbot-dns-cloudflare
  fi
  
  # 1.2 Set up Cloudflare credentials
  echo "🔑 Setting up Cloudflare credentials..."
  mkdir -p /etc/letsencrypt/cloudflare
  cat > /etc/letsencrypt/cloudflare/credentials.ini << 'EOF'
# Cloudflare API credentials used by Certbot
dns_cloudflare_api_token = lLrGrv3Q8hmj-Db4ncotnGqbaE0IFX9oKvD8yxQV
EOF
  chmod 600 /etc/letsencrypt/cloudflare/credentials.ini
  
  # 1.3 Get the wildcard certificate
  echo "🔒 Obtaining wildcard certificate..."
  certbot certonly \
    --dns-cloudflare \
    --dns-cloudflare-credentials /etc/letsencrypt/cloudflare/credentials.ini \
    --non-interactive \
    --agree-tos \
    --email admin@online-aesthetik.de \
    -d "*.s-neue.website" \
    -d "s-neue.website"
else
  echo "✅ Wildcard certificate is already set up."
fi

# 2. Make sure SSL modules are enabled
echo "🔌 Enabling Apache SSL modules..."
a2enmod ssl
a2enmod headers
a2enmod rewrite

# 3. Create an SSL template for virtual hosts
echo "📝 Creating Apache SSL template..."
cat > /etc/apache2/sites-available/ssl-vhost-template.conf << 'EOF'
<IfModule mod_ssl.c>
  <VirtualHost *:443>
    ServerName SUBDOMAIN.s-neue.website
    DocumentRoot /var/www/SUBDOMAIN
    
    <Directory /var/www/SUBDOMAIN>
      Options FollowSymLinks
      AllowOverride All
      Require all granted
    </Directory>
    
    ErrorLog ${APACHE_LOG_DIR}/error-SUBDOMAIN.log
    CustomLog ${APACHE_LOG_DIR}/access-SUBDOMAIN.log combined
    
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/s-neue.website/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/s-neue.website/privkey.pem
    Include /etc/letsencrypt/options-ssl-apache.conf
  </VirtualHost>
</IfModule>
EOF

# 4. Create a direct script to enable SSL for a specific site
echo "📝 Creating direct SSL enablement script..."
cat > /opt/infra-scripts/enable-site-ssl.sh << 'EOF'
#!/usr/bin/env bash
set -eo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <subdomain>"
  exit 1
fi

SUB="$1"
DOMAIN="s-neue.website"
FQDN="${SUB}.${DOMAIN}"

echo "🔒 Enabling SSL for ${FQDN}..."

# Verify the site config exists
HTTP_CONF="/etc/apache2/sites-available/${SUB}.conf"
if [ ! -f "$HTTP_CONF" ]; then
  echo "❌ Site configuration not found: ${HTTP_CONF}"
  exit 1
fi

# Create SSL config from template
SSL_CONF="/etc/apache2/sites-available/${SUB}-ssl.conf"
cp /etc/apache2/sites-available/ssl-vhost-template.conf "$SSL_CONF"
sed -i "s/SUBDOMAIN/${SUB}/g" "$SSL_CONF"

# Add redirect from HTTP to HTTPS in the original config
if ! grep -q "RewriteEngine On" "$HTTP_CONF"; then
  sed -i '/<VirtualHost \*:80>/a \
  RewriteEngine On\
  RewriteRule ^(.*)$ https://%{HTTP_HOST}$1 [R=301,L]' "$HTTP_CONF"
fi

# Enable the SSL site
a2ensite "${SUB}-ssl.conf"

# Reload Apache
systemctl reload apache2

echo "✅ SSL enabled for ${FQDN}"
echo "🔗 Site now available at https://${FQDN}"
EOF
chmod +x /opt/infra-scripts/enable-site-ssl.sh
ln -sf /opt/infra-scripts/enable-site-ssl.sh /usr/local/bin/enable-site-ssl

# 5. Now modify the wordpress setup script to automatically enable SSL
echo "📝 Modifying WordPress setup script to include SSL setup..."
WP_SETUP_SCRIPT="/opt/infra-scripts/wordpress/setup_wp.sh"

# Backup the original script
cp "$WP_SETUP_SCRIPT" "${WP_SETUP_SCRIPT}.bak.$(date +%s)"

# Check the end of the current script
SCRIPT_END=$(tail -5 "$WP_SETUP_SCRIPT")
if ! echo "$SCRIPT_END" | grep -q "SSL"; then
  # Add SSL setup to the end of the script
  cat >> "$WP_SETUP_SCRIPT" << 'EOF'

# Automatically set up SSL for the site
echo "🔒 Setting up SSL for ${SUB}..."
/opt/infra-scripts/enable-site-ssl.sh "${SUB}"

echo "✅ WordPress setup complete with SSL."
echo "🔗 URL: https://${SUB}.s-neue.website"
echo "👤 Admin: we-admin / We-25-\$\$-Vo"
EOF
  echo "✅ SSL setup added to WordPress installation script."
else
  echo "✅ SSL setup is already included in the WordPress script."
fi

# 6. Create script to enable SSL for all existing sites
echo "📝 Creating script to enable SSL for all existing sites..."
cat > /opt/infra-scripts/enable-all-ssl.sh << 'EOF'
#!/usr/bin/env bash
set -eo pipefail

echo "🔍 Finding all WordPress sites..."
SITES=$(find /etc/apache2/sites-enabled/ -name "*.conf" | grep -v "ssl.conf" | grep -v "000-default" | grep -v "default-ssl")

if [ -z "$SITES" ]; then
  echo "No sites found."
  exit 0
fi

for SITE_CONF in $SITES; do
  SITE_FILE=$(basename "$SITE_CONF")
  SUB="${SITE_FILE%.conf}"
  
  echo "🔒 Enabling SSL for ${SUB}..."
  /opt/infra-scripts/enable-site-ssl.sh "${SUB}" || echo "⚠️ Failed to enable SSL for ${SUB}"
done

echo "✅ SSL enabled for all sites."
EOF
chmod +x /opt/infra-scripts/enable-all-ssl.sh
ln -sf /opt/infra-scripts/enable-all-ssl.sh /usr/local/bin/enable-all-ssl

# 7. Enable SSL for existing sites
echo "🔄 Enabling SSL for existing sites..."
/opt/infra-scripts/enable-all-ssl.sh

# 8. Set up automatic SSL renewal (if not already done)
echo "🔄 Setting up automatic certificate renewal..."
if ! grep -q "certbot renew" /etc/crontab; then
  echo "0 3 * * * root certbot renew --quiet --post-hook 'systemctl reload apache2'" >> /etc/crontab
  echo "✅ Automatic renewal scheduled."
else
  echo "✅ Automatic renewal already configured."
fi

# 9. Fix the specific site mentioned by the user
echo "🔧 Fixing SSL for testkunde10 specifically..."
if [ -f "/etc/apache2/sites-available/testkunde10.conf" ]; then
  enable-site-ssl testkunde10
  echo "✅ SSL fixed for testkunde10."
else
  echo "⚠️ Site configuration for testkunde10 not found."
fi

echo "✅ Automatic SSL setup complete!"
echo ""
echo "Now all new WordPress sites will automatically have SSL enabled."
echo "If you still have issues with a specific site, run:"
echo "enable-site-ssl sitename"
echo ""
echo "To test, visit: https://testkunde10.s-neue.website"