#!/usr/bin/env bash
set -euo pipefail

# This script updates Cloudflare tokens in all necessary files

echo "🔑 Updating Cloudflare tokens..."

# Update the Cloudflare environment file
echo "📝 Updating /etc/profile.d/cloudflare.sh"
cat > /etc/profile.d/cloudflare.sh << 'EOF'
# Cloudflare configuration
export CF_API_TOKEN="lLrGrv3Q8hmj-Db4ncotnGqbaE0IFX9oKvD8yxQV"
export ZONE_ID="d7e5b4cfe310063ede065b1ba06bcdf7"
export DOMAIN="s-neue.website"
EOF
chmod +x /etc/profile.d/cloudflare.sh

# Apply the configuration to current shell
source /etc/profile.d/cloudflare.sh

# Verify the environment variables
echo "✅ Tokens set:"
echo "CF_API_TOKEN: ${CF_API_TOKEN:0:5}...${CF_API_TOKEN:(-5)}"
echo "ZONE_ID: ${ZONE_ID}"
echo "DOMAIN: ${DOMAIN}"

# Check for any other places tokens might need to be updated
echo "🔍 Checking for other places tokens might be hardcoded..."

HARDCODED_FILES=$(grep -r --include="*.sh" --include="*.php" "lLrGrv3Q8hmj-Db4ncotnGqbaE0IFX9oKvD8yxQV\|d7e5b4cfe310063ede065b1ba06bcdf7" /opt --color=never || echo "No hardcoded tokens found")

if [ -n "$HARDCODED_FILES" ]; then
  echo "⚠️ Found potentially hardcoded tokens in these files:"
  echo "$HARDCODED_FILES"
  echo ""
  echo "You should consider updating these files to use environment variables instead."
else
  echo "✅ No hardcoded tokens found in scripts."
fi

echo ""
echo "✅ Cloudflare tokens updated successfully!"
echo ""
echo "To use these tokens in the current session, run:"
echo "  source /etc/profile.d/cloudflare.sh"
echo ""
echo "For WordPress installation:"
echo "1. Disable test mode:  bash /opt/infra-scripts/test-mode.sh disable"
echo "2. Run setup:          setup_wp testkunde1"