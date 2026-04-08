#!/bin/bash
set -euo pipefail

FRONTEND_IP="${1:-10.0.10.105}"
DB_IP="${2:-10.0.10.106}"
SERVICE_TOKEN="${3:-$(openssl rand -hex 24)}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
