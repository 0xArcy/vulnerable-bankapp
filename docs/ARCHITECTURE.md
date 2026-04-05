# Modern Bank CTF - Architecture & Deployment Guide

## System Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                        MODERN BANK 3-TIER LAB                          │
├─────────────────────┬──────────────────────┬──────────────────────────┤
│                     │                      │                          │
│  FRONTEND TIER      │  BACKEND TIER        │  DATABASE TIER           │
│  (Public)           │  (Internal)          │  (Private)               │
│                     │                      │                          │
│  Ubuntu LTS         │  Ubuntu Server 24    │  Windows 10              │
│  192.168.1.10       │  192.168.1.100       │  192.168.1.50            │
│                     │                      │                          │
│  • Apache2          │  • Node.js Express   │  • SQL Server Express    │
│  • PHP 8.1+         │  • CGI Admin (PHP)   │  • OpenSSH (optional)    │
│  • PHP FPM          │  • Port 8080         │  • Port 1433 (MSSQL)     │
│  • Port 80, 443     │                      │  • Port 3389 (RDP)       │
│                     │                      │  • Port 445 (SMB)        │
│                     │                      │                          │
└─────────────────────┴──────────────────────┴──────────────────────────┘
     ↓                        ↓                        ↓
  PUBLIC              INTERNAL/BACKEND         INTERNAL/SECURE
 Internet          Backend Services          Database Services
  Exposed           & Aggregation           Data Storage & Auth
```

---

## Deployment Instructions

### Prerequisites

1. **Virtualization Platform:** VirtualBox, Proxmox, ESXi, or VMware
2. **Network Configuration:**
   - Create isolated virtual network (192.168.1.0/24)
   - Firewall: pfSense or similar for network segmentation
   - Frontend: Expose ports 80, 443 to external
   - Backend: Internal only (between Frontend & Database)
   - Database: Internal only (from Backend only)

3. **VM Specifications:**
   - **Frontend:** Ubuntu LTS (2+ CPU, 2GB RAM, 20GB disk)
   - **Backend:** Ubuntu Server 24 (2+ CPU, 2GB RAM, 20GB disk)
   - **Database:** Windows 10 (2+ CPU, 4GB RAM, 30GB disk)

---

### Tier 1: Frontend Deployment

#### 1.1 Prepare VM

```bash
# Boot Ubuntu LTS
# Configure network:
#   Static IP: 192.168.1.10
#   Gateway: 192.168.1.1
#   DNS: 8.8.8.8

# SSH into VM
ssh ubuntu@192.168.1.10

# Update system
sudo apt update && sudo apt upgrade -y

# Install git (if not present)
sudo apt install git -y
```

#### 1.2 Clone and Deploy

```bash
# Clone repository
cd /tmp
git clone <your-repo> threetier
cd threetier/frontend

# Run setup script
sudo bash setup_frontend.sh 192.168.1.100

# This will:
# - Install Apache2, PHP, dependencies
# - Deploy web application
# - Create /uploads directory (writable)
# - Inject Backend IP into configuration
# - Configure firewall
# - Start Apache service
```

#### 1.3 Verify Installation

```bash
# Check Apache status
sudo systemctl status apache2

# Test access
curl http://localhost

# Verify credentials file exists
ls -la /var/www/html/.env
ls -la /var/www/html/uploads

# Test login page
curl -s http://localhost | grep "Modern Bank"
```

---

### Tier 2: Backend Deployment

#### 2.1 Prepare VM

```bash
# Boot Ubuntu Server 24
# Configure network:
#   Static IP: 192.168.1.100
#   Gateway: 192.168.1.1

# SSH into VM
ssh ubuntu@192.168.1.100

# Update system
sudo apt update && sudo apt upgrade -y
```

#### 2.2 Clone and Deploy

```bash
# Clone repository
cd /tmp
git clone <your-repo> threetier
cd threetier/backend

# Run setup script with IPs
sudo bash setup_backend.sh 192.168.1.10 192.168.1.50

# This will:
# - Install Node.js, npm
# - Deploy backend API
# - Create .env with credentials
# - Start Node.js service
# - Configure firewall
# - Install PHP for CGI endpoints
```

#### 2.3 Verify Installation

```bash
# Check service status
sudo systemctl status modernbank-backend

# Test API
curl http://localhost:8080/api/health

# Test vulnerable endpoints
curl http://localhost:8080/api/config

# Verify credentials exist
ls -la /opt/modernbank-backend/.env
```

---

### Tier 3: Database Deployment (Windows)

#### 3.1 Prepare Windows VM

```powershell
# Boot Windows 10
# Configure network:
#   Static IP: 192.168.1.50
#   Gateway: 192.168.1.1
#   DNS: 8.8.8.8

# Install SQL Server Express (if not present)
# Download from: https://www.microsoft.com/en-us/sql-server/sql-server-editions-express

# Install with defaults:
# - Instance: SQLEXPRESS
# - Authentication: Mixed (SQL + Windows)
# - Collation: Latin1_General_CI_AS
```

#### 3.2 Deploy Database

```powershell
# Using PowerShell (Run as Administrator)
cd C:\temp\threetier\database

# Run setup script
PowerShell -ExecutionPolicy Bypass -File .\setup_database.ps1 `
    -BackendIP 192.168.1.100 `
    -DatabaseName ModernBank `
    -AdminUser Administrator `
    -AdminPassword "ModernBank@2024!Admin"

# Or using Batch (if PowerShell unavailable)
setup_database.bat 192.168.1.100
```

#### 3.3 Verify Installation

```powershell
# Check SQL Server service
Get-Service | Where-Object {$_.Name -like "*SQL*"}

# Connect to database
sqlcmd -S localhost\SQLEXPRESS

# By Query:
# SELECT DB_NAME()
# GO

# Verify database created
# USE ModernBank
# SELECT COUNT(*) FROM Users
# GO
```

#### 3.4 Configure Firewall

```powershell
# Rules should be configured automatically
# Verify:

# Check MSSQL access from Backend
netsh advfirewall firewall show rule name="MSSQL from Backend"

# Check RDP access
netsh advfirewall firewall show rule name="RDP from Backend"
```

---

## Network Topology Verification

### From Frontend (192.168.1.10):

```bash
# Can reach Backend
ping 192.168.1.100
curl http://192.168.1.100:8080/api/health

# Cannot reach Database directly (should be blocked)
ping 192.168.1.50  # May timeout
```

### From Backend (192.168.1.100):

```bash
# Can reach Frontend
curl http://192.168.1.10

# Can reach Database
nmap -p 1433 192.168.1.50  # Should see MSSQL open

# SSH to Database (if configured)
ssh Administrator@192.168.1.50
```

### From Database (192.168.1.50):

```powershell
# Can accept Backend connections
netstat -an | findstr 1433

# Can reach Backend via SMB
net view \\192.168.1.100

# Cannot reach Frontend directly (should be blocked)
ping 192.168.1.10  # May fail
```

---

## CTF Configuration Options

### Option 1: Full Exposure (Easy)
- All tiers accessible from any network
- Firewall rules wide open
- Credentials in multiple locations
- **Scenario:** New attacker, first-time CTF

### Option 2: Segmented (Medium) - **RECOMMENDED**
- Frontend: Public access (80,443)
- Backend: Internal only (8080 from Frontend)
- Database: Internal only (1433, 3389 from Backend)
- **Scenario:** Standard security posture

### Option 3: Hardened (Difficult)
- Frontend: VPN-only or whitelist IPs
- Backend: Firewall only from Frontend specifically
- Database: Firewall only from Backend specifically
- Additional: Enable SELinux/AppArmor
- **Scenario:** Advanced team, focused on exploitation

### Option 4: Custom Rules via pfSense

```
# Frontend VLAN (10)
- Inbound: 80/tcp, 443/tcp from any
- Outbound: To Backend VLAN (20) any port

# Backend VLAN (20)
- Inbound: 8080/tcp from Frontend VLAN only
- Outbound: To Database VLAN (30) port 1433, 3389, 445

# Database VLAN (30)
- Inbound: 1433/tcp, 3389/tcp, 445/tcp from Backend VLAN only
- Outbound: Blocked or very restricted
```

---

## Troubleshooting

### Frontend Issues

**Apache not starting:**
```bash
sudo systemctl status apache2
sudo apache2ctl configtest

# Check logs
sudo tail -f /var/log/apache2/error.log
```

**PHP shell upload not executing:**
```bash
# Verify permissions
ls -la /var/www/html/uploads/

# Should see: drwxr-xr-x with execute for all

# Verify PHP executes
echo '<?php phpinfo(); ?>' > /tmp/test.php
php /tmp/test.php
```

### Backend Issues

**Node.js service not starting:**
```bash
sudo systemctl status modernbank-backend
sudo journalctl -u modernbank-backend -n 50

# Manual start to see errors
cd /opt/modernbank-backend && npm install
node server.js
```

**Cannot connect to Node API:**
```bash
# Check if listening
netstat -tulpn | grep 8080

# Try locally
curl localhost:8080/api/health

# Test from Frontend
ssh ubuntu@192.168.1.10
curl http://192.168.1.100:8080/api/health
```

### Database Issues

**SQL Server not starting:**
```powershell
# From Services:
services.msc
# Find "SQL Server (SQLEXPRESS)" and start

# Or via PowerShell:
Start-Service -Name "MSSQL$SQLEXPRESS"
```

**Cannot connect from Backend:**
```bash
# From Backend, install tools:
apt-get install mssql-tools

# Try to connect:
sqlcmd -S 192.168.1.50 -U Administrator -P "ModernBank@2024!Admin"

# Or test with nmap:
nmap -sV -p 1433 192.168.1.50
```

---

## Maintenance & Reset

### Reset Frontend

```bash
sudo systemctl stop apache2
sudo rm -rf /var/www/html/*
sudo rm -rf /var/www/html/uploads/*
sudo bash /home/ubuntu/setup_frontend.sh  192.168.1.100
```

### Reset Backend

```bash
sudo systemctl stop modernbank-backend
sudo rm -rf /opt/modernbank-backend/*
sudo bash /home/ubuntu/setup_backend.sh 192.168.1.10 192.168.1.50
```

### Reset Database

```powershell
# Connect and drop database:
sqlcmd -S localhost\SQLEXPRESS
# DROP DATABASE ModernBank;
# GO

# Re-run setup:
PowerShell -ExecutionPolicy Bypass -File .\setup_database.ps1
```

---

## Performance Tuning

### Frontend
- Apache workers: `MaxRequestWorkers = 256`
- PHP-FPM: Increase pool size
- Upload limit: 50MB

### Backend
- Node.js cluster mode: For multi-core
- Connection pooling: For database

### Database
- SQL Server memory: 2GB minimum
- Transaction log: Size appropriately

---

## Documentation Files

- `KILL_CHAIN.md` - Complete exploitation walkthrough
- `VULNERABILITIES.md` - Detailed vulnerability descriptions
- `ARCHITECTURE.md` - This file, system design

