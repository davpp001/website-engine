#!/usr/bin/env bash
set -euo pipefail

# This script fixes the setup issues after the directory structure changes

echo "🔧 Fixing website-engine setup..."

# 1. Check the current directory structure
echo "📂 Checking directory structure..."
ls -la /opt

# 2. Create correct directory structure if needed
echo "🔧 Creating directory structure..."
mkdir -p /opt/infra-scripts/wordpress
mkdir -p /opt/infra-scripts/cloudflare
mkdir -p /opt/infra-playbooks
mkdir -p /usr/local/bin

# 3. Copy files from current location to the correct structure
echo "📋 Copying files to the right locations..."

# Only try to copy if the source directory exists
if [ -d "/opt/website-engine/infra-scripts" ]; then
  echo "Found /opt/website-engine/infra-scripts directory, copying files..."
  cp -r /opt/website-engine/infra-scripts/* /opt/infra-scripts/
elif [ -d "/opt/website-engine/website-engine-infra-scripts" ]; then
  echo "Found /opt/website-engine/website-engine-infra-scripts directory, copying files..."
  cp -r /opt/website-engine/website-engine-infra-scripts/* /opt/infra-scripts/
else
  echo "❌ Error: Could not find infra-scripts directory"
  ls -la /opt/website-engine
  exit 1
fi

# Copy infra-playbooks
if [ -d "/opt/website-engine/infra-playbooks" ]; then
  echo "Found /opt/website-engine/infra-playbooks directory, copying files..."
  cp -r /opt/website-engine/infra-playbooks/* /opt/infra-playbooks/
else
  echo "❌ Error: Could not find infra-playbooks directory"
  ls -la /opt/website-engine
  exit 1
fi

# 4. Create symlinks manually
echo "🔗 Creating symlinks to scripts..."

# WordPress scripts
if [ -f "/opt/infra-scripts/wordpress/install_wp.sh" ]; then
  ln -sf /opt/infra-scripts/wordpress/install_wp.sh /usr/local/bin/install_wp
  chmod +x /opt/infra-scripts/wordpress/install_wp.sh
  echo "Created symlink for install_wp"
else
  echo "⚠️ Warning: Could not find install_wp.sh"
  find /opt -name "install_wp.sh" 2>/dev/null
fi

if [ -f "/opt/infra-scripts/wordpress/uninstall_wp.sh" ]; then
  ln -sf /opt/infra-scripts/wordpress/uninstall_wp.sh /usr/local/bin/uninstall_wp
  chmod +x /opt/infra-scripts/wordpress/uninstall_wp.sh
  echo "Created symlink for uninstall_wp"
else
  echo "⚠️ Warning: Could not find uninstall_wp.sh"
  find /opt -name "uninstall_wp.sh" 2>/dev/null
fi

if [ -f "/opt/infra-scripts/wordpress/setup_wp.sh" ]; then
  ln -sf /opt/infra-scripts/wordpress/setup_wp.sh /usr/local/bin/setup_wp
  chmod +x /opt/infra-scripts/wordpress/setup_wp.sh
  echo "Created symlink for setup_wp"
else
  echo "⚠️ Warning: Could not find setup_wp.sh"
  find /opt -name "setup_wp.sh" 2>/dev/null
fi

if [ -f "/opt/infra-scripts/wordpress/cleanup_wp.sh" ]; then
  ln -sf /opt/infra-scripts/wordpress/cleanup_wp.sh /usr/local/bin/cleanup_wp
  chmod +x /opt/infra-scripts/wordpress/cleanup_wp.sh
  echo "Created symlink for cleanup_wp"
else
  echo "⚠️ Warning: Could not find cleanup_wp.sh"
  find /opt -name "cleanup_wp.sh" 2>/dev/null
fi

# Cloudflare scripts
if [ -f "/opt/infra-scripts/cloudflare/create_cf_sub_auto.sh" ]; then
  ln -sf /opt/infra-scripts/cloudflare/create_cf_sub_auto.sh /usr/local/bin/create_cf_sub_auto
  chmod +x /opt/infra-scripts/cloudflare/create_cf_sub_auto.sh
  echo "Created symlink for create_cf_sub_auto"
else
  echo "⚠️ Warning: Could not find create_cf_sub_auto.sh"
  find /opt -name "create_cf_sub_auto.sh" 2>/dev/null
fi

if [ -f "/opt/infra-scripts/cloudflare/delete_cf_sub.sh" ]; then
  ln -sf /opt/infra-scripts/cloudflare/delete_cf_sub.sh /usr/local/bin/delete_cf_sub
  chmod +x /opt/infra-scripts/cloudflare/delete_cf_sub.sh
  echo "Created symlink for delete_cf_sub"
else
  echo "⚠️ Warning: Could not find delete_cf_sub.sh"
  find /opt -name "delete_cf_sub.sh" 2>/dev/null
fi

# Create pullinfra command
cat > /usr/local/bin/pullinfra << 'EOF'
#!/bin/bash
cd /opt/infra-scripts && git pull origin main
cd /opt/infra-playbooks && git pull origin main
EOF
chmod +x /usr/local/bin/pullinfra
echo "Created pullinfra command"

# 5. Set up Cloudflare credentials
if [ ! -f "/etc/profile.d/cloudflare.sh" ]; then
  echo "☁️ Creating Cloudflare configuration file..."
  cat > /etc/profile.d/cloudflare.sh << 'EOF'
export CF_API_TOKEN="your-cloudflare-token"
export ZONE_ID="your-zone-id"
EOF
  chmod +x /etc/profile.d/cloudflare.sh
  echo "Created Cloudflare configuration file"
fi

# Verify the setup
echo "🔍 Verifying setup..."
ls -la /usr/local/bin/setup_wp /usr/local/bin/install_wp /usr/local/bin/create_cf_sub_auto 2>/dev/null || echo "Some symlinks are missing"
ls -la /opt/infra-scripts/wordpress /opt/infra-scripts/cloudflare 2>/dev/null || echo "Directory structure incomplete"

echo "⚠️ IMPORTANT: Edit /etc/profile.d/cloudflare.sh and add your Cloudflare credentials!"
echo "Then run: source /etc/profile.d/cloudflare.sh"

echo "✅ Setup fix complete!"
echo "You can now use commands like 'install_wp', 'create_cf_sub_auto', etc."