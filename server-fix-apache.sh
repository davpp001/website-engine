#!/usr/bin/env bash
set -euo pipefail

# Fix Apache and set up environment properly

echo "🔧 Fixing Apache and environment issues..."

# 1. Start Apache service
echo "🌐 Starting Apache service..."
systemctl start apache2
systemctl status apache2

# 2. Set up proper Cloudflare configuration
echo "☁️ Setting up Cloudflare configuration..."
cat > /etc/profile.d/cloudflare.sh << 'EOF'
export CF_API_TOKEN="your-cloudflare-token"
export ZONE_ID="your-zone-id"
export DOMAIN="s-neue.website"
EOF
chmod +x /etc/profile.d/cloudflare.sh
source /etc/profile.d/cloudflare.sh

# 3. Create a local testing function for the WordPress script
echo "🧪 Creating test environment..."
cat > /opt/infra-scripts/wordpress/test-mode.sh << 'EOF'
#!/bin/bash

# Override DNS check in setup_wp.sh for testing
function setup_test_mode() {
  # Backup the original file
  cp /opt/infra-scripts/wordpress/setup_wp.sh /opt/infra-scripts/wordpress/setup_wp.sh.bak
  
  # Replace the DNS check with a simulated success
  sed -i 's/if dig +short "${SUB}.s-neue.website" | grep -q/if echo "217.154.235.137" | grep -q/g' /opt/infra-scripts/wordpress/setup_wp.sh
}

# Restore the original setup script
function restore_setup() {
  if [ -f "/opt/infra-scripts/wordpress/setup_wp.sh.bak" ]; then
    mv /opt/infra-scripts/wordpress/setup_wp.sh.bak /opt/infra-scripts/wordpress/setup_wp.sh
    echo "Original setup script restored"
  else
    echo "No backup found"
  fi
}

case "$1" in
  "enable")
    setup_test_mode
    echo "Test mode enabled - DNS checks will be bypassed"
    ;;
  "disable")
    restore_setup
    echo "Test mode disabled - original functionality restored"
    ;;
  *)
    echo "Usage: $0 {enable|disable}"
    exit 1
    ;;
esac
EOF
chmod +x /opt/infra-scripts/wordpress/test-mode.sh

# 4. Fix Apache configuration if needed
echo "📝 Ensuring Apache configuration..."
a2enmod ssl
systemctl restart apache2

echo "✅ Fixes applied!"
echo ""
echo "To test site creation in test mode (without DNS):"
echo "1. First enable test mode:  bash /opt/infra-scripts/wordpress/test-mode.sh enable"
echo "2. Run the setup:          setup_wp testkunde1"
echo "3. Disable test mode:      bash /opt/infra-scripts/wordpress/test-mode.sh disable"
echo ""
echo "To use with real DNS, edit /etc/profile.d/cloudflare.sh with your credentials"
echo "and run: source /etc/profile.d/cloudflare.sh"