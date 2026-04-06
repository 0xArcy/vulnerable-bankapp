#!/bin/bash
# Deployment Checklist for Modern Bank CTF Lab
# Use this to verify all components are properly deployed

echo "=================================================="
echo "Modern Bank CTF Lab - Deployment Verification"
echo "=================================================="
echo ""

FRONTEND_IP="${1:-192.168.1.10}"
BACKEND_IP="${2:-192.168.1.100}"
DATABASE_IP="${3:-192.168.1.50}"

check_mark="✓"
cross_mark="✗"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() {
    echo -e "${GREEN}${check_mark}${NC} $1"
}

fail() {
    echo -e "${RED}${cross_mark}${NC} $1"
}

warn() {
    echo -e "${YELLOW}!${NC} $1"
}

echo "======== FRONTEND TIER ($FRONTEND_IP) ========"
echo ""

# Check Frontend connectivity
if ping -c 1 "$FRONTEND_IP" &> /dev/null; then
    pass "Frontend VM is reachable"
else
    fail "Frontend VM is NOT reachable"
    exit 1
fi

# Check Apache
if nc -zw1 "$FRONTEND_IP" 80 &> /dev/null; then
    pass "Apache (port 80) is listening"
else
    fail "Apache (port 80) is NOT listening"
fi

# Check web application
if curl -s "http://$FRONTEND_IP/" | grep -q "Modern Bank"; then
    pass "Web application is responding"
else
    fail "Web application is NOT responding properly"
fi

# Check .env file
if curl -s "http://$FRONTEND_IP/.env" | grep -q "BACKEND_IP"; then
    pass ".env file is accessible (vulnerability confirmed)"
else
    fail ".env file is NOT accessible"
fi

# Check uploads directory
if curl -s "http://$FRONTEND_IP/uploads/" | grep -q "Index of"; then
    pass "Uploads directory is browsable (vulnerability confirmed)"
else
    warn "Uploads directory may not be browsable"
fi

echo ""
echo "======== BACKEND TIER ($BACKEND_IP) ========"
echo ""

# Check Backend connectivity
if ping -c 1 "$BACKEND_IP" &> /dev/null; then
    pass "Backend VM is reachable"
else
    fail "Backend VM is NOT reachable"
fi

# Check API port
if nc -zw1 "$BACKEND_IP" 8080 &> /dev/null; then
    pass "Backend API (port 8080) is listening"
else
    fail "Backend API (port 8080) is NOT listening"
fi

# Check health endpoint
if curl -s "http://$BACKEND_IP:8080/api/health" | grep -q "ok"; then
    pass "Backend API health check is responding"
else
    fail "Backend API health endpoint is NOT working"
fi

# Check config endpoint (should expose credentials)
if curl -s "http://$BACKEND_IP:8080/api/config" | grep -q "windows_credentials"; then
    pass "API config endpoint is exposing credentials (vulnerability confirmed)"
else
    fail "API config endpoint NOT exposing credentials properly"
fi

# Check backend to database connectivity check
if curl -s "http://$BACKEND_IP:8080/api/db-status" | grep -q "\"database_reachable\":true"; then
    pass "Backend reports database port is reachable"
else
    warn "Backend db-status endpoint says database is unreachable (or endpoint unavailable)"
fi

# Check admin endpoint
if curl -s "http://$BACKEND_IP:8080/cgi-bin/admin.php?action=info" | grep -q "windows"; then
    pass "Admin CGI endpoint is responding (vulnerability confirmed)"
else
    fail "Admin CGI endpoint is NOT responding"
fi

echo ""
echo "======== DATABASE TIER ($DATABASE_IP) ========"
echo ""

# Check Database connectivity
if ping -c 1 "$DATABASE_IP" &> /dev/null; then
    pass "Database VM is reachable"
else
    fail "Database VM is NOT reachable"
fi

# Check MSSQL port
if nc -zw1 "$DATABASE_IP" 1433 &> /dev/null; then
    pass "MSSQL (port 1433) is listening"
else
    fail "MSSQL (port 1433) is NOT listening"
fi

# Check RDP port
if nc -zw1 "$DATABASE_IP" 3389 &> /dev/null; then
    pass "RDP (port 3389) is listening"
else
    fail "RDP (port 3389) is NOT listening"
fi

# Check SMB port
if nc -zw1 "$DATABASE_IP" 445 &> /dev/null; then
    pass "SMB (port 445) is listening"
else
    fail "SMB (port 445) is NOT listening"
fi

echo ""
echo "======== NETWORK CONNECTIVITY ========"
echo ""

# Check Frontend to Backend
if ping -c 1 "$BACKEND_IP" &> /dev/null; then
    pass "Frontend can reach Backend"
else
    fail "Frontend CANNOT reach Backend"
fi

# Check Backend API from Frontend
if curl -s "http://$BACKEND_IP:8080/api/health" | grep -q "ok"; then
    pass "Frontend can access Backend API"
else
    fail "Frontend CANNOT access Backend API"
fi

echo ""
echo "======== CREDENTIALS ========"
echo ""
echo "Frontend:"
echo "  Admin: admin / admin123"
echo "  User: user / user123"
echo ""
echo "Backend SSH:"
echo "  User: deploy"
echo "  Pass: DeployPass123!Vulnerable"
echo ""
echo "Database:"
echo "  Server: $DATABASE_IP\\SQLEXPRESS"
echo "  Admin: Administrator / ModernBank@2024!Admin"
echo "  User: bankapp / BankApp@2024!Insecure"
echo ""

echo "======== NEXT STEPS ========"
echo ""
echo "1. Access Frontend: http://$FRONTEND_IP"
echo "2. Login with: admin/admin123"
echo "3. Upload PHP shell via profile picture"
echo "4. Read .env file to get Backend credentials"
echo "5. SSH to Backend: ssh deploy@$BACKEND_IP"
echo "6. Access Backend API for Windows credentials"
echo "7. Connect to MSSQL: sqlcmd -S $DATABASE_IP -U Administrator -P \"ModernBank@2024!Admin\""
echo ""
echo "See docs/KILL_CHAIN.md for complete exploitation guide"
echo ""
