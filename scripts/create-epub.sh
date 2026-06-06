#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
manuscript_builder="$script_dir/create-manuscript.sh"
manuscript_file="$repo_root/MANUSCRIPT.md"
cover_file="$repo_root/cover.png"
output_file="$repo_root/What It Feels Like To Be Us.epub"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

require_file() {
  if [[ ! -f "$1" ]]; then
    printf 'Required file not found: %s\n' "$1" >&2
    exit 1
  fi
}

require_command pandoc
require_file "$manuscript_builder"
require_file "$cover_file"

bash "$manuscript_builder"
require_file "$manuscript_file"

pandoc "$manuscript_file" \
  --from markdown \
  --to epub3 \
  --toc \
  --toc-depth=2 \
  --split-level=2 \
  --metadata title="What It Feels Like to Be Us" \
  --metadata author="Joshua Szepietowski" \
  --metadata lang="en-US" \
  --resource-path="$repo_root" \
  --epub-cover-image="$cover_file" \
  --output "$output_file"

printf 'Wrote %s\n' "$output_file"
