#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v supabase >/dev/null 2>&1; then
  echo "supabase CLI not found in PATH" >&2
  exit 1
fi

supabase stop --project-id dls-platform-manager "$@" >/dev/null 2>&1 || true
exec supabase stop --project-id supabase-safe "$@"
