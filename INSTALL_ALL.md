# ZERO-CLICK MODERNBANK DEPLOYMENT GUIDE

The entire deployment infrastructure has been securely refactored to an encrypted-by-default, tokenized stack utilizing:
- **MongoDB (Windows 10, Port 27017)**: Authenticated local Community Server with backend-only firewall access.
- **Node.js Backend (Ubuntu Server, Port 8443)**: Express API protected by internal tokens and TLS.
- **Nginx Frontend Proxy (Ubuntu OS, Port 443)**: Static JS app acting as the API gateway.

## Environment Variables / IP Config
| Node | IP Address | Subnet | Role |
|------|------------|--------|------|
| **Database** | `10.0.10.106` | /24 | Windows 10, MongoDB TLS |
| **Backend** | `10.0.10.102` | /24 | Ubuntu Server, Node.js + systemd |
| **Frontend** | `10.0.10.105` | /24 | Ubuntu OS, JS app + Nginx |

---

## 1. Deploy Database (Windows 10)
Run the script on Windows 10 (`10.0.10.106`) as **Administrator**.

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\database\setup_mongo.ps1
```
The fixed backend IP is already built in, so no IP argument is required in the standard environment.

## 2. Deploy Backend (Ubuntu Server)
Connect to `10.0.10.102`.

```bash
sudo bash ./backend/setup_node.sh
```

The fixed frontend and database IPs plus the shared repo token are already built in.

## 3. Deploy Frontend (Ubuntu OS)
Connect to `10.0.10.105`.

```bash
sudo bash ./frontend/setup_nginx_proxy.sh
```

## 4. Verification Check
Use the pre-built verification script from your orchestration machine:

```bash
bash verify_stack.sh
```

Everything is fully migrated from PHP to JS, and from clear-text SQL to Encrypted MongoDB!
