#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env.local"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing .env.local. Copy .env.example and fill local API keys first." >&2
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

flutter run \
  --dart-define="ETHERSCAN_API_KEY=${ETHERSCAN_API_KEY:-}" \
  --dart-define="TRONGRID_API_KEY=${TRONGRID_API_KEY:-}" \
  --dart-define="HELIUS_API_KEY=${HELIUS_API_KEY:-}" \
  "$@"
