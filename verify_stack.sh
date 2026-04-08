#!/bin/bash
set -euo pipefail

FRONTEND_IP="${1:-10.0.10.105}"
BACKEND_IP="${2:-10.0.10.102}"
DB_IP="${3:-10.0.10.106}"
SERVICE_TOKEN="${4:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULTS_FILE="$SCRIPT_DIR/deployment.defaults.env"

if [[ -f "$DEFAULTS_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$DEFAULTS_FILE"
fi

if [[ -z "$SERVICE_TOKEN" ]]; then
    SERVICE_TOKEN="${DEFAULT_INTERNAL_API_TOKEN:-}"
fi

echo "Verifying Modern Bank stack for frontend ${FRONTEND_IP}, backend ${BACKEND_IP}, database ${DB_IP}..."

echo "1. Testing frontend TLS"
if curl -sk "https://${FRONTEND_IP}" | grep -q "Modern Bank"; then
    echo " - Frontend check OK"
else
    echo " - Frontend check FAILED"
fi

echo "2. Testing backend auth through frontend proxy"
LOGIN_RESPONSE="$(curl -sk -X POST "https://${FRONTEND_IP}/api/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"username":"julia.ross","password":"BankDemo!2026"}')"

ACCESS_TOKEN="$(echo "$LOGIN_RESPONSE" | sed -n 's/.*"accessToken":"\([^"]*\)".*/\1/p')"

if [[ -n "$ACCESS_TOKEN" ]]; then
    echo " - Frontend proxy login OK"
else
    echo " - Frontend proxy login FAILED"
fi

echo "3. Testing backend direct health with internal token"
if [[ -n "$SERVICE_TOKEN" ]] && curl -sk "https://${BACKEND_IP}:8443/api/health" -H "X-Internal-Token: ${SERVICE_TOKEN}" | grep -q '"status":"ok"'; then
    echo " - Backend direct channel OK"
else
    echo " - Backend direct channel FAILED"
fi

echo "4. Database host reachability"
if nc -zw2 "$DB_IP" 27017 >/dev/null 2>&1; then
    echo " - MongoDB port reachable"
else
    echo " - MongoDB port not reachable from this machine"
fi

echo "Done"
