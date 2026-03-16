#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_step() {
  local script_path="$1"

  if [[ ! -f "$script_path" ]]; then
    printf 'Missing required script: %s\n' "$script_path" >&2
    exit 1
  fi

  printf 'Running %s\n' "$(basename "$script_path")"
  bash "$script_path"
}

run_step "$script_dir/create-manuscript.sh"
run_step "$script_dir/create-pdf.sh"
run_step "$script_dir/create-website.sh"

printf 'All artifacts created successfully.\n'