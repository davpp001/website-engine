#!/usr/bin/env bash
set -euo pipefail

# Quick fix script to fix the immediate issues

echo "🔧 Applying quick fixes to website-engine..."

# 1. Start Apache
echo "🌐 Starting Apache..."
systemctl start apache2
systemctl status apache2

# 2. Fix the setup_wp.sh script to match the current server IP
echo "📝 Adjusting setup_wp.sh script..."
SERVER_IP=$(curl -s https://ifconfig.me)

# Create a backup of the original file
cp /opt/infra-scripts/wordpress/setup_wp.sh /opt/infra-scripts/wordpress/setup_wp.sh.bak

# Update the IP address in the file
sed -i "s/217.160.252.118/$SERVER_IP/g" /opt/infra-scripts/wordpress/setup_wp.sh

# Adjust grep pattern in case there are issues with capturing subdomain
sed -i 's/grep -oP .*/grep -o "[a-zA-Z0-9-]*" | head -1)/' /opt/infra-scripts/wordpress/setup_wp.sh

echo "✅ Fixed IP address in setup_wp.sh to use $SERVER_IP instead of 217.160.252.118"

# 3. Ensure proper CloudFlare environment
echo "☁️ Setting up Cloudflare environment file..."
cat > /etc/profile.d/cloudflare.sh << EOF
export CF_API_TOKEN="your-cloudflare-token"
export ZONE_ID="your-zone-id" 
export DOMAIN="s-neue.website"
EOF
chmod +x /etc/profile.d/cloudflare.sh
source /etc/profile.d/cloudflare.sh

# 4. Create a test mode script for bypassing DNS checks
echo "🧪 Creating test mode script..."
cat > /opt/infra-scripts/test-mode.sh << 'EOF'
#!/bin/bash
set -euo pipefail

if [ "$1" == "enable" ]; then
  echo "Enabling test mode..."
  # Backup the original file if not already backed up
  if [ ! -f "/opt/infra-scripts/wordpress/setup_wp.sh.orig" ]; then
    cp /opt/infra-scripts/wordpress/setup_wp.sh /opt/infra-scripts/wordpress/setup_wp.sh.orig
  fi
  
  # Create a modified version that skips DNS check
  cat > /opt/infra-scripts/wordpress/setup_wp.sh << 'TEST_MODE'
#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <subdomain>"
  exit 1
fi

BASE="$1"
SUB="$BASE"

# Hartkodiertes Repo-Verzeichnis
INFRA_DIR="/opt/infra-scripts"

echo "🌐 TEST MODE: Simuliere Subdomain $SUB…"
echo "✅ TEST MODE: DNS-Check übersprungen."

echo "📦 Installiere WordPress für $SUB…"
# Echte Install-Funktion mit absolutem Pfad aufrufen
bash "$INFRA_DIR/wordpress/install_wp.sh" "$SUB"

echo "✅ setup_wp für $SUB abgeschlossen."
TEST_MODE
  chmod +x /opt/infra-scripts/wordpress/setup_wp.sh
  
  echo "✅ Test mode enabled. DNS checks will be bypassed."
  echo "Run 'setup_wp testkunde1' to test installation."
  
elif [ "$1" == "disable" ]; then
  echo "Disabling test mode..."
  if [ -f "/opt/infra-scripts/wordpress/setup_wp.sh.orig" ]; then
    cp /opt/infra-scripts/wordpress/setup_wp.sh.orig /opt/infra-scripts/wordpress/setup_wp.sh
    echo "✅ Original setup script restored."
  else
    echo "❌ Original backup not found. Cannot restore."
  fi
else
  echo "Usage: $0 {enable|disable}"
  exit 1
fi
EOF
chmod +x /opt/infra-scripts/test-mode.sh

echo "✅ All quick fixes applied!"
echo ""
echo "To test WordPress installation without DNS:"
echo "1. Enable test mode:  bash /opt/infra-scripts/test-mode.sh enable"
echo "2. Run setup:         setup_wp testkunde1"
echo "3. Disable test mode: bash /opt/infra-scripts/test-mode.sh disable"
echo ""
echo "For production use, edit /etc/profile.d/cloudflare.sh with your credentials"
echo "and run: source /etc/profile.d/cloudflare.sh"