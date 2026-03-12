#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck disable=SC1091
source "${root_dir}/scripts/load-root-env.sh"

if ! command -v supabase >/dev/null 2>&1; then
  echo "supabase CLI not found in PATH" >&2
  exit 1
fi

tmp_dir="${root_dir}/.temp/supabase-safe"
"${root_dir}/scripts/supabase-safe-config.sh" >/dev/null

exec supabase start --workdir "${tmp_dir}" "$@"
