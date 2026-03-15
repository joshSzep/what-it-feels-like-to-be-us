#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
chapters_dir="$repo_root/chapters"
output_file="$repo_root/MANUSCRIPT.md"

strip_chapter_heading() {
  awk '
    NR == 1 && /^# / {
      stripped = 1
      next
    }
    NR == 2 && stripped && $0 == "" {
      next
    }
    {
      print
    }
  ' "$1"
}

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

{
  printf '# What It Feels Like to Be Us\n\n'
  printf 'A novel by Joshua Szepietowski\n'

  shopt -s nullglob

  for act_dir in "$chapters_dir"/*/; do
    act_name="$(basename "$act_dir")"

    printf '\n## %s\n' "$act_name"

    for chapter_file in "$act_dir"/*.md; do
      chapter_name="$(basename "$chapter_file" .md)"

      printf '\n### %s\n\n' "$chapter_name"
      strip_chapter_heading "$chapter_file"
      printf '\n'
    done
  done
} > "$tmp_file"

mv "$tmp_file" "$output_file"
trap - EXIT

printf 'Wrote %s\n' "$output_file"