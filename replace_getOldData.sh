#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=${1:-.}
AWK_SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
AWK_SCRIPT="$AWK_SCRIPT_DIR/replace_getOldData.awk"

if command -v gawk >/dev/null 2>&1; then
  AWK_CMD="gawk"
elif command -v awk >/dev/null 2>&1; then
  AWK_CMD="awk"
else
  echo "Error: gawk or awk is required" >&2
  exit 1
fi

mapfile -t FILES < <(grep -IlR --include='*.cpp' -e 'getOldData' "$ROOT_DIR" || true)

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "No .cpp files with getOldData found." >&2
  exit 0
fi

for f in "${FILES[@]}"; do
  tmp=$(mktemp)
  "$AWK_CMD" -f "$AWK_SCRIPT" "$f" > "$tmp"
  if ! cmp -s "$f" "$tmp"; then
    cp -- "$f" "$f.bak"
    mv -- "$tmp" "$f"
    echo "Updated: $f (backup: $f.bak)"
  fi
  [[ -f "$tmp" ]] && rm -f "$tmp" || true

done


