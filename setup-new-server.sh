#!/usr/bin/env bash
set -euo pipefail

# Website Engine - Neuer Server Setup Script
# Dieses Skript automatisiert die Einrichtung der Website Engine auf einem neuen Server

echo "🚀 Website Engine - Neuer Server Setup"
echo "======================================"

# 1. Grundlegende Pakete installieren
echo "📦 Installiere benötigte Pakete..."
apt update && apt upgrade -y
apt install -y git curl jq unzip zip nano apache2 mysql-server php php-cli php-mysql \
  php-curl php-xml php-mbstring php-zip php-gd php-intl libapache2-mod-php \
  software-properties-common bash-completion shellcheck python3-pip certbot python3-certbot-apache python3-certbot-dns-cloudflare

# 2. Apache-Module aktivieren
echo "🌐 Aktiviere Apache-Module..."
a2enmod rewrite ssl headers
systemctl restart apache2

# 3. MySQL einrichten
echo "🗃️ Richte MySQL ein..."
systemctl enable mysql
systemctl start mysql

# Erstelle wordpressuser
echo "Erstelle MySQL-Benutzer 'wordpressuser'..."
mysql -u root -e "CREATE USER IF NOT EXISTS 'wordpressuser'@'localhost' IDENTIFIED BY 'password';"
mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'wordpressuser'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"

# 4. WP-CLI installieren
echo "⚙️ Installiere WP-CLI..."
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

# 5. Verzeichnisstruktur erstellen
echo "📂 Erstelle Verzeichnisstruktur..."
mkdir -p /opt/infra-scripts/wordpress
mkdir -p /opt/infra-scripts/cloudflare
mkdir -p /opt/infra-playbooks

# 6. Skripte kopieren (Repo muss bereits geklont sein)
if [ -d "/opt/website-engine" ]; then
  echo "🔄 Kopiere Skripte aus vorhandenem Repository..."
  
  # Prüfe auf infra-scripts Verzeichnis
  if [ -d "/opt/website-engine/infra-scripts" ]; then
    cp -r /opt/website-engine/infra-scripts/* /opt/infra-scripts/
    echo "✅ /opt/website-engine/infra-scripts kopiert"
  elif [ -d "/opt/website-engine/website-engine-infra-scripts" ]; then
    cp -r /opt/website-engine/website-engine-infra-scripts/* /opt/infra-scripts/
    echo "✅ /opt/website-engine/website-engine-infra-scripts kopiert"
  else
    echo "⚠️ Keine infra-scripts gefunden"
  fi
  
  # Prüfe auf infra-playbooks
  if [ -d "/opt/website-engine/infra-playbooks" ]; then
    cp -r /opt/website-engine/infra-playbooks/* /opt/infra-playbooks/
    echo "✅ /opt/website-engine/infra-playbooks kopiert"
  else
    echo "⚠️ Keine infra-playbooks gefunden"
  fi
else
  echo "⚠️ Repository /opt/website-engine nicht gefunden"
  echo "Führe folgende Befehle manuell aus:"
  echo "git clone https://github.com/DEIN_BENUTZERNAME/website-engine.git /opt/website-engine"
  echo "Danach dieses Skript erneut ausführen"
  exit 1
fi

# 7. Erstelle Symlinks für Befehle
echo "🔗 Erstelle Symlinks für Befehle..."
ln -sf /opt/infra-scripts/wordpress/setup_wp.sh /usr/local/bin/setup_wp
ln -sf /opt/infra-scripts/wordpress/cleanup_wp.sh /usr/local/bin/cleanup_wp
ln -sf /opt/infra-scripts/wordpress/install_wp.sh /usr/local/bin/install_wp
ln -sf /opt/infra-scripts/wordpress/uninstall_wp.sh /usr/local/bin/uninstall_wp
ln -sf /opt/infra-scripts/cloudflare/create_cf_sub_auto.sh /usr/local/bin/create_cf_sub_auto
ln -sf /opt/infra-scripts/cloudflare/delete_cf_sub.sh /usr/local/bin/delete_cf_sub

# 8. Erstelle pullinfra Befehl
echo "📋 Erstelle pullinfra Befehl..."
cat > /usr/local/bin/pullinfra << 'EOF'
#!/bin/bash
cd /opt/infra-scripts && git pull origin main
cd /opt/infra-playbooks && git pull origin main
EOF
chmod +x /usr/local/bin/pullinfra

# 9. Cloudflare-Konfiguration
echo "☁️ Erstelle Cloudflare-Konfiguration..."
cat > /etc/profile.d/cloudflare.sh << 'EOF'
export CF_API_TOKEN="lLrGrv3Q8hmj-Db4ncotnGqbaE0IFX9oKvD8yxQV"
export ZONE_ID="d7e5b4cfe310063ede065b1ba06bcdf7"
export DOMAIN="s-neue.website"
EOF
chmod +x /etc/profile.d/cloudflare.sh
source /etc/profile.d/cloudflare.sh

# 10. Certbot Cloudflare-Konfiguration
echo "🔒 Erstelle Certbot Cloudflare-Konfiguration..."
mkdir -p /etc/letsencrypt/cloudflare
cat > /etc/letsencrypt/cloudflare/credentials.ini << 'EOF'
# Cloudflare API credentials used by Certbot
dns_cloudflare_api_token = lLrGrv3Q8hmj-Db4ncotnGqbaE0IFX9oKvD8yxQV
EOF
chmod 600 /etc/letsencrypt/cloudflare/credentials.ini

# 11. Fix-Permissions-Skript erstellen
echo "🔧 Erstelle Fix-Permissions-Skript..."
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

# 12. Wildcard-SSL-Zertifikat einrichten (optional)
echo "🔒 Möchtest du ein Wildcard-SSL-Zertifikat einrichten? (j/n)"
read -r SETUP_SSL

if [[ "$SETUP_SSL" == "j" ]]; then
  echo "🔒 Erstelle Wildcard-SSL-Zertifikat..."
  certbot certonly \
    --dns-cloudflare \
    --dns-cloudflare-credentials /etc/letsencrypt/cloudflare/credentials.ini \
    --non-interactive \
    --agree-tos \
    --email admin@online-aesthetik.de \
    -d "*.s-neue.website" \
    -d "s-neue.website"
  
  echo "✅ Wildcard-SSL-Zertifikat erstellt"
else
  echo "⏩ Wildcard-SSL-Zertifikat überspringen"
fi

echo ""
echo "✅ Setup abgeschlossen!"
echo ""
echo "Du kannst jetzt folgende Befehle verwenden:"
echo "- setup_wp <subdomain>    - WordPress-Installation mit Subdomain erstellen"
echo "- cleanup_wp <subdomain>  - WordPress-Installation entfernen"
echo "- fix-wp-permissions <subdomain> - Berechtigungen reparieren"
echo ""
echo "Führe einen Test durch mit: setup_wp test"