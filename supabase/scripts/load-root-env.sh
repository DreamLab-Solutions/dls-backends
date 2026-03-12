#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../../.." && pwd)"
root_env_file="${repo_root}/.env.local"

if [[ -f "${root_env_file}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${root_env_file}"
  set +a
fi
