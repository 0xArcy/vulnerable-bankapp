#!/bin/bash
set -euo pipefail

# Fixed lab topology defaults:
# Frontend 10.0.10.105, Backend 10.0.10.102.
# You can run this wrapper with no arguments in the standard deployment.

BACKEND_IP="${1:-10.0.10.102}"
SERVICE_TOKEN="${2:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULTS_FILE="$(cd "$SCRIPT_DIR/.." && pwd)/deployment.defaults.env"

if [[ -f "$DEFAULTS_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$DEFAULTS_FILE"
fi

if [[ -z "$SERVICE_TOKEN" ]]; then
  SERVICE_TOKEN="${DEFAULT_INTERNAL_API_TOKEN:-}"
fi

echo "Setting up Frontend proxy stack (Ubuntu OS 10.0.10.105)..."
echo "Backend IP: ${BACKEND_IP}"

if [[ "$EUID" -ne 0 ]]; then
  echo "Please run as root"
  exit 1
fi

exec bash "$SCRIPT_DIR/setup_frontend.sh" "$BACKEND_IP" "$SERVICE_TOKEN"
