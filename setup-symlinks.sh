#!/usr/bin/env bash
set -euo pipefail

# This script sets up symlinks for all command-line tools
# after the repository merger and renaming.

# Base directories (adjust these paths as needed)
INFRA_SCRIPTS_DIR="/opt/infra-scripts"
INFRA_PLAYBOOKS_DIR="/opt/infra-playbooks"

# Create bin directory if it doesn't exist
mkdir -p /usr/local/bin

# Create symlinks for WordPress tools
ln -sf "${INFRA_SCRIPTS_DIR}/wordpress/install_wp.sh" /usr/local/bin/install_wp
ln -sf "${INFRA_SCRIPTS_DIR}/wordpress/uninstall_wp.sh" /usr/local/bin/uninstall_wp
ln -sf "${INFRA_SCRIPTS_DIR}/wordpress/setup_wp.sh" /usr/local/bin/setup_wp
ln -sf "${INFRA_SCRIPTS_DIR}/wordpress/cleanup_wp.sh" /usr/local/bin/cleanup_wp

# Create symlinks for Cloudflare tools
ln -sf "${INFRA_SCRIPTS_DIR}/cloudflare/create_cf_sub_auto.sh" /usr/local/bin/create_cf_sub_auto
ln -sf "${INFRA_SCRIPTS_DIR}/cloudflare/delete_cf_sub.sh" /usr/local/bin/delete_cf_sub

# Create pullinfra command
cat > /usr/local/bin/pullinfra << 'EOF'
#!/bin/bash
cd /opt/infra-scripts && git pull origin main
cd /opt/infra-playbooks && git pull origin main
EOF
chmod +x /usr/local/bin/pullinfra

echo "✅ All symlinks created successfully."
echo "You can now use commands like 'install_wp', 'create_cf_sub_auto', etc."