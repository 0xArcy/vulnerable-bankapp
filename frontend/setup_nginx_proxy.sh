#!/bin/bash
set -euo pipefail

BACKEND_IP="${1:-10.0.10.102}"
SERVICE_TOKEN="${2:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up Frontend proxy stack (Ubuntu OS 10.0.10.105)..."
echo "Backend IP: ${BACKEND_IP}"

if [[ "$EUID" -ne 0 ]]; then
  echo "Please run as root"
  exit 1
fi

if [[ -z "$SERVICE_TOKEN" ]]; then
    echo "Usage: sudo bash setup_nginx_proxy.sh <BACKEND_IP> <SERVICE_TOKEN>"
    exit 1
fi

exec bash "$SCRIPT_DIR/setup_frontend.sh" "$BACKEND_IP" "$SERVICE_TOKEN"
