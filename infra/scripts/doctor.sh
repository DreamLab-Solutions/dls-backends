#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if ! command -v docker >/dev/null 2>&1; then
  echo "[doctor] docker is not installed"
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "[doctor] docker is installed but not running"
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "[doctor] docker compose plugin missing"
  exit 1
fi

echo "[doctor] docker OK"

echo "[doctor] expected URLs"
cat <<EOF_URLS
- http://hub.localhost (Hub Console)
- http://api.hub.localhost (Hub API)
- http://paperless.localhost (Paperless)
- http://payload.localhost (Payload Admin)
EOF_URLS

echo "[doctor] env files"
if [ -f "$ROOT_DIR/.env" ]; then
  echo "- .env found"
else
  echo "- .env missing (copy .env.example)"
fi

if [ -f "$ROOT_DIR/../dev/paperless/docker-compose.env" ]; then
  echo "- dev/paperless/docker-compose.env found"
else
  echo "- dev/paperless/docker-compose.env missing (run: make sync-env)"
fi
