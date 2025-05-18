#!/usr/bin/env bash
set -euo pipefail

# This script sets up a new server with the merged repository structure
# and correct directory names.

echo "🚀 Setting up new server for website-engine..."

# 1. Install basic dependencies
echo "📦 Installing system packages..."
apt-get update && apt-get upgrade -y
apt-get install -y \
  git \
  curl \
  jq \
  unzip \
  zip \
  nano \
  apache2 \
  mysql-server \
  php \
  php-cli \
  php-mysql \
  php-curl \
  php-xml \
  php-mbstring \
  php-zip \
  php-gd \
  php-intl \
  libapache2-mod-php \
  software-properties-common \
  bash-completion \
  shellcheck \
  python3-pip \
  ansible

# 2. Set up Apache
echo "🌐 Setting up Apache..."
systemctl enable apache2
systemctl start apache2
a2enmod rewrite
systemctl reload apache2

# 3. Install WP-CLI
echo "🔧 Installing WP-CLI..."
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

# 4. Set up Certbot for SSL
echo "🔒 Installing Certbot..."
apt install -y certbot python3-certbot-apache python3-certbot-dns-cloudflare

# 5. Create directory structure
echo "📂 Creating directory structure..."
mkdir -p /opt/infra-scripts
mkdir -p /opt/infra-playbooks

# 6. Clone the repository with the correct structure
echo "📥 Cloning repository..."
REPO_URL="https://github.com/YOUR_USERNAME/website-engine.git"
cd /opt
git clone "$REPO_URL" temp-repo

# Copy with the new directory names
echo "📋 Copying files to correct locations..."
cp -r temp-repo/website-engine-infra-scripts/* /opt/infra-scripts/
cp -r temp-repo/infra-playbooks/* /opt/infra-playbooks/
rm -rf temp-repo

# 7. Set up symlinks for all commands
echo "🔗 Setting up command symlinks..."
bash /opt/infra-scripts/setup-symlinks.sh

# 8. Set up Cloudflare credentials (user needs to edit this file)
echo "☁️ Creating Cloudflare configuration file..."
cat > /etc/profile.d/cloudflare.sh << 'EOF'
export CF_API_TOKEN="your-cloudflare-token"
export ZONE_ID="your-zone-id"
EOF
chmod +x /etc/profile.d/cloudflare.sh

echo "⚠️ IMPORTANT: Edit /etc/profile.d/cloudflare.sh and add your Cloudflare credentials!"
echo "Then run: source /etc/profile.d/cloudflare.sh"

# 9. Run the Ansible playbook (this requires user input for the vault password)
echo "🔧 Setup complete! To finish configuration, run:"
echo "cd /opt/infra-playbooks && ansible-playbook -i inventory.yml site.yml --ask-vault-pass"

echo "✅ Server setup complete!"
echo "You can now use commands like 'install_wp', 'create_cf_sub_auto', etc."