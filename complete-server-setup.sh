#!/usr/bin/env bash
set -euo pipefail

# Complete server setup script that addresses all the issues
# and provides a robust testing environment

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
function print_section() {
  echo -e "\n${BLUE}$1${NC}"
  echo "========================================"
}

function print_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

function print_warning() {
  echo -e "${YELLOW}⚠️ $1${NC}"
}

function print_error() {
  echo -e "${RED}❌ $1${NC}"
}

function check_command() {
  if command -v "$1" >/dev/null 2>&1; then
    print_success "Command $1 is available"
    return 0
  else
    print_error "Command $1 is not available"
    return 1
  fi
}

print_section "WEBSITE ENGINE - COMPLETE SERVER SETUP"
echo "This script will set up the complete website engine environment."

# 1. Check system requirements
print_section "Checking system requirements"
required_cmds=("curl" "jq" "apache2" "php" "mysql" "wp")

for cmd in "${required_cmds[@]}"; do
  check_command "$cmd" || missing_cmd=1
done

if [[ -n "${missing_cmd:-}" ]]; then
  print_warning "Some required commands are missing. Installing dependencies..."
  
  apt-get update && apt-get upgrade -y
  apt-get install -y curl jq apache2 mysql-server php php-cli php-mysql php-curl php-xml \
    php-mbstring php-zip php-gd php-intl libapache2-mod-php
  
  if ! check_command "wp"; then
    print_section "Installing WP-CLI"
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    mv wp-cli.phar /usr/local/bin/wp
    print_success "WP-CLI installed"
  fi
fi

# 2. Ensure Apache is running
print_section "Setting up Apache"
if systemctl is-active --quiet apache2; then
  print_success "Apache is already running"
else
  print_warning "Apache is not running. Starting Apache..."
  systemctl start apache2
  if systemctl is-active --quiet apache2; then
    print_success "Apache started successfully"
  else
    print_error "Could not start Apache. Please check Apache logs."
    exit 1
  fi
fi

# Enable required modules
a2enmod rewrite ssl
systemctl reload apache2
print_success "Apache modules enabled"

# 3. Set up directory structure
print_section "Setting up directory structure"
mkdir -p /opt/infra-scripts/wordpress
mkdir -p /opt/infra-scripts/cloudflare
mkdir -p /opt/infra-playbooks
print_success "Directory structure created"

# 4. Ensure all scripts are in the right place
print_section "Checking script locations"

# First check if we're being run from the git repo directory
if [[ -d "./infra-scripts" && -d "./infra-playbooks" ]]; then
  print_success "Running from git repo directory"
  SCRIPTS_SOURCE="./infra-scripts"
  PLAYBOOKS_SOURCE="./infra-playbooks"
elif [[ -d "/opt/website-engine/infra-scripts" && -d "/opt/website-engine/infra-playbooks" ]]; then
  print_success "Using scripts from /opt/website-engine"
  SCRIPTS_SOURCE="/opt/website-engine/infra-scripts"
  PLAYBOOKS_SOURCE="/opt/website-engine/infra-playbooks"
else
  print_error "Could not find script directories. Please check your repository structure."
  exit 1
fi

# Copy scripts to proper locations
print_section "Copying scripts to proper locations"
cp -r "$SCRIPTS_SOURCE/"* /opt/infra-scripts/
cp -r "$PLAYBOOKS_SOURCE/"* /opt/infra-playbooks/
print_success "Scripts copied to proper locations"

# 5. Set up command symlinks
print_section "Setting up command symlinks"
ln -sf /opt/infra-scripts/wordpress/install_wp.sh /usr/local/bin/install_wp
ln -sf /opt/infra-scripts/wordpress/uninstall_wp.sh /usr/local/bin/uninstall_wp
ln -sf /opt/infra-scripts/wordpress/setup_wp.sh /usr/local/bin/setup_wp
ln -sf /opt/infra-scripts/wordpress/cleanup_wp.sh /usr/local/bin/cleanup_wp
ln -sf /opt/infra-scripts/cloudflare/create_cf_sub_auto.sh /usr/local/bin/create_cf_sub_auto
ln -sf /opt/infra-scripts/cloudflare/delete_cf_sub.sh /usr/local/bin/delete_cf_sub

# Make all scripts executable
chmod +x /opt/infra-scripts/wordpress/*.sh
chmod +x /opt/infra-scripts/cloudflare/*.sh

# Create pullinfra command
cat > /usr/local/bin/pullinfra << 'EOF'
#!/bin/bash
cd /opt/infra-scripts && git pull origin main
cd /opt/infra-playbooks && git pull origin main
EOF
chmod +x /usr/local/bin/pullinfra
print_success "Command symlinks created"

# 6. Set up Cloudflare configuration
print_section "Setting up Cloudflare configuration"
SERVER_IP=$(curl -s https://ifconfig.me)

cat > /etc/profile.d/cloudflare.sh << EOF
export CF_API_TOKEN="your-cloudflare-token"
export ZONE_ID="your-zone-id"
export DOMAIN="s-neue.website"
EOF
chmod +x /etc/profile.d/cloudflare.sh
source /etc/profile.d/cloudflare.sh
print_success "Cloudflare configuration created"

# 7. Create test environment
print_section "Creating test environment"
cat > /opt/infra-scripts/wordpress/test-mode.sh << 'EOF'
#!/bin/bash
set -euo pipefail

# Override DNS check in setup_wp.sh for testing
function setup_test_mode() {
  # Backup the original file
  cp /opt/infra-scripts/wordpress/setup_wp.sh /opt/infra-scripts/wordpress/setup_wp.sh.bak
  
  # Replace the DNS check with a simulated success
  sed -i 's/dig +short "${SUB}.s-neue.website" | grep -q/echo "127.0.0.1" | grep -q/g' /opt/infra-scripts/wordpress/setup_wp.sh
  
  echo "Test mode enabled - DNS checks will be bypassed"
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
    ;;
  "disable")
    restore_setup
    ;;
  *)
    echo "Usage: $0 {enable|disable}"
    exit 1
    ;;
esac
EOF
chmod +x /opt/infra-scripts/wordpress/test-mode.sh
print_success "Test environment created"

# 8. Create MySQL user for WordPress if needed
print_section "Setting up MySQL for WordPress"
MYSQL_USER="wordpressuser"
MYSQL_PASSWORD="password"  # You should change this

if mysql -u root -e "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = '$MYSQL_USER')" 2>/dev/null | grep -q 1; then
  print_success "MySQL user $MYSQL_USER already exists"
else
  print_warning "Creating MySQL user for WordPress..."
  mysql -u root -e "CREATE USER '$MYSQL_USER'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';"
  mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO '$MYSQL_USER'@'localhost' WITH GRANT OPTION;"
  mysql -u root -e "FLUSH PRIVILEGES;"
  print_success "MySQL user created"
fi

# 9. Final verification
print_section "Final verification"
# Check command symlinks
for cmd in install_wp uninstall_wp setup_wp cleanup_wp create_cf_sub_auto delete_cf_sub pullinfra; do
  if [ -L "/usr/local/bin/$cmd" ]; then
    print_success "Command $cmd is properly linked"
  else
    print_error "Command $cmd is not properly linked"
  fi
done

# Check Apache is running
if systemctl is-active --quiet apache2; then
  print_success "Apache is running"
else
  print_error "Apache is not running"
fi

# 10. Instructions for the user
print_section "SETUP COMPLETE"
echo -e "${GREEN}Your server is now set up! Here are the next steps:${NC}"
echo
echo -e "${YELLOW}1. Add your Cloudflare credentials${NC}"
echo "   Edit /etc/profile.d/cloudflare.sh and add your API token and zone ID"
echo "   Then run: source /etc/profile.d/cloudflare.sh"
echo
echo -e "${YELLOW}2. Test WordPress installation${NC}"
echo "   To test with DNS bypass:"
echo "   a. Enable test mode:  bash /opt/infra-scripts/wordpress/test-mode.sh enable"
echo "   b. Run setup:         setup_wp testkunde1"
echo "   c. Disable test mode: bash /opt/infra-scripts/wordpress/test-mode.sh disable"
echo
echo -e "${YELLOW}3. For production use${NC}"
echo "   a. Make sure your Cloudflare credentials are set"
echo "   b. Run: create_cf_sub_auto kunde1"
echo "   c. Run: install_wp kunde1"
echo
echo -e "${YELLOW}4. To update scripts from git${NC}"
echo "   Run: pullinfra"
echo
echo -e "${GREEN}Your server IP is: $SERVER_IP${NC}"