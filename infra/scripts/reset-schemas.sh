#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${PWD}/.env"
if [[ ! -f "${ENV_FILE}" ]]; then
  ENV_FILE="${ROOT_DIR}/.env"
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing .env at repo root. Copy .env.example to .env and fill values."
  exit 1
fi

declare -A ENV_MAP
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
    key="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"
    if [[ "$value" =~ ^\"(.*)\"$ ]]; then
      value="${BASH_REMATCH[1]}"
    elif [[ "$value" =~ ^\'(.*)\'$ ]]; then
      value="${BASH_REMATCH[1]}"
    fi
    ENV_MAP["$key"]="$value"
  fi
done < "${ENV_FILE}"

DB_URI="${ENV_MAP[DATABASE_URI]:-${ENV_MAP[DATABASE_URI_CORE]:-${ENV_MAP[DATABASE_URI_PAYLOAD]:-${ENV_MAP[DATABASE_URI_PAPERLESS]:-}}}}"
if [[ -z "${DB_URI}" ]]; then
  echo "DATABASE_URI is not set in .env."
  exit 1
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "psql not found. Install postgresql-client or run from a host with psql."
  exit 1
fi

SCHEMAS=("hub" "paperless" "payload")
if [[ "${1:-}" == "--include-public" || "${RESET_PUBLIC:-false}" == "true" ]]; then
  SCHEMAS=("public" "hub" "paperless" "payload")
fi

echo "About to DROP and RECREATE schemas: ${SCHEMAS[*]}"
if [[ "${DB_URI}" =~ ^(postgres|postgresql):// ]]; then
  REDACTED="${DB_URI}"
  REDACTED="${REDACTED//:\/\/[^@]*@/:\/\/***:***@}"
  echo "Database: ${REDACTED}"
else
  echo "Database: [redacted]"
fi
read -r -p "Type 'reset' to continue: " CONFIRM
if [[ "${CONFIRM}" != "reset" ]]; then
  echo "Aborted."
  exit 1
fi

SQL=""
for schema in "${SCHEMAS[@]}"; do
  SQL+="DROP SCHEMA IF EXISTS ${schema} CASCADE;"
  SQL+="CREATE SCHEMA ${schema};"
done

psql "${DB_URI}" -v ON_ERROR_STOP=1 -c "${SQL}"
echo "Schemas reset complete."
