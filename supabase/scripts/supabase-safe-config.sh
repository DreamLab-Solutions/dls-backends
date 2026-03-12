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
project_dir="${tmp_dir}/supabase"
mkdir -p "${project_dir}"

src_config="${root_dir}/config.toml"
if [[ ! -f "${src_config}" ]]; then
  echo "Missing ${src_config}" >&2
  exit 1
fi

dst_config="${project_dir}/config.toml"
raw_config="${project_dir}/config.raw.toml"

awk '
  BEGIN { in_oauth = 0 }
  /^\[auth\.oauth_server\]/ { in_oauth = 1; next }
  {
    if (in_oauth) {
      if ($0 ~ /^\[/) { in_oauth = 0; print }
      next
    }
    print
  }
' "${src_config}" > "${raw_config}"

cat >> "${raw_config}" <<'TOML'

[auth.oauth_server]
enabled = false
TOML

node "${root_dir}/scripts/render-safe-config.mjs" "${raw_config}" "${dst_config}"

for path in migrations seeds functions; do
  ln -sfn "${root_dir}/${path}" "${project_dir}/${path}"
done

echo "${tmp_dir}"
