#!/bin/bash
set -euo pipefail

# Fixed lab topology defaults:
# Frontend 10.0.10.105, Backend 10.0.10.102, Database 10.0.10.106.
# You can run this wrapper with no arguments in the standard deployment.

FRONTEND_IP="${1:-10.0.10.105}"
DB_IP="${2:-10.0.10.106}"
SERVICE_TOKEN="${3:-${INTERNAL_API_TOKEN:-}}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULTS_FILE="$(cd "$SCRIPT_DIR/.." && pwd)/deployment.defaults.env"

if [[ -f "$DEFAULTS_FILE" ]]; then
  # Load repo-wide deployment defaults such as the shared internal token.
  # shellcheck disable=SC1090
  source "$DEFAULTS_FILE"
fi

if [[ -z "$SERVICE_TOKEN" ]]; then
  SERVICE_TOKEN="${DEFAULT_INTERNAL_API_TOKEN:-$(openssl rand -hex 24)}"
fi

echo "Setting up Backend (Ubuntu Server 10.0.10.102)..."
echo "Frontend IP: ${FRONTEND_IP}"
echo "Database IP: ${DB_IP}"

if [[ "$EUID" -ne 0 ]]; then
  echo "Please run as root"
  exit 1
fi

export MONGO_DB_NAME="modernbank"
export MONGO_APP_USER="modernbank_app"
export MONGO_APP_PASSWORD="ModernBankMongo!2026"
export MONGO_USE_TLS="false"

exec bash "$SCRIPT_DIR/setup_backend.sh" "$FRONTEND_IP" "$DB_IP" "$SERVICE_TOKEN"
