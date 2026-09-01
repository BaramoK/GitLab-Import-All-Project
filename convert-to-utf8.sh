#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

TARGET_DIR="$1"

if [ ! -d "$TARGET_DIR" ]; then
    echo "Directory not found: $TARGET_DIR"
    exit 1
fi

echo "🔍 Scanning $TARGET_DIR"
echo "--------------------------------"

find "$TARGET_DIR" -type f | while read -r file; do

    # Skip obvious binary files
    if ! file "$file" | grep -qiE 'text|utf|ascii'; then
        continue
    fi

    # Already valid UTF-8 ?
    if iconv -f UTF-8 -t UTF-8 "$file" -o /dev/null 2>/dev/null; then
        continue
    fi

    echo "⚠️ Converting: $file"

    tmp="${file}.tmp"

    # Try UTF-16 (LE & BE)
    if iconv -f UTF-16 -t UTF-8 "$file" -o "$tmp" 2>/dev/null; then
        mv "$tmp" "$file"
        echo "   ✔ Converted from UTF-16"
        continue
    fi

    # Try ISO-8859-1
    if iconv -f ISO-8859-1 -t UTF-8 "$file" -o "$tmp" 2>/dev/null; then
        mv "$tmp" "$file"
        echo "   ✔ Converted from ISO-8859-1"
        continue
    fi

    # Try Windows-1252
    if iconv -f WINDOWS-1252 -t UTF-8 "$file" -o "$tmp" 2>/dev/null; then
        mv "$tmp" "$file"
        echo "   ✔ Converted from WINDOWS-1252"
        continue
    fi

    # Last resort: force-clean invalid characters
    if iconv -f UTF-8 -t UTF-8 -c "$file" -o "$tmp" 2>/dev/null; then
        mv "$tmp" "$file"
        echo "   ⚠ Cleaned invalid UTF-8 characters"
        continue
    fi

    echo "   ❌ Could not convert: $file"
    rm -f "$tmp"
done

echo "--------------------------------"
echo "✅ Done"
