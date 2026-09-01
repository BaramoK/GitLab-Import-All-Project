#!/usr/bin/env bash

set -euo pipefail

# ─── Helpers ──────────────────────────────────────────
die() { echo "$1" >&2; exit 1; }

try_convert() {
    local file="$1" tmp="$2" from="$3"
    iconv -f "$from" -t UTF-8 "$file" -o "$tmp" 2>/dev/null || return 1
    mv "$tmp" "$file"
    echo "   ✔ Converted from $from"
}

try_clean() {
    local file="$1" tmp="$2"
    iconv -f UTF-8 -t UTF-8 -c "$file" -o "$tmp" 2>/dev/null || return 1
    mv "$tmp" "$file"
    echo "   ⚠ Cleaned invalid UTF-8 characters"
}

process_file() {
    local file="$1" tmp="$2"

    # Guard clauses
    [ -L "$file" ] && { echo "🔗 Symlink ignoré: $file"; return; }
    file "$file" | grep -qiE 'text|utf|ascii' || return
    iconv -f UTF-8 -t UTF-8 "$file" -o /dev/null 2>/dev/null && return

    echo "⚠️ Converting: $file"

    try_convert "$file" "$tmp" "UTF-16" && return
    try_convert "$file" "$tmp" "ISO-8859-1" && return
    try_convert "$file" "$tmp" "WINDOWS-1252" && return
    try_clean "$file" "$tmp" && return

    echo "   ❌ Could not convert: $file"
}

# ─── Guard clauses : validations ──────────────────────
[ "$#" -ne 1 ] && die "Usage: $0 <directory>"
[ ! -d "$1" ] && die "Directory not found: $1"

TARGET_DIR="$1"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "🔍 Scanning $TARGET_DIR"
echo "--------------------------------"

while IFS= read -r -d '' file; do
    process_file "$file" "$TMPDIR/$(basename "$file").tmp"
done < <(find "$TARGET_DIR" -type f -print0)

echo "--------------------------------"
echo "✅ Done"
