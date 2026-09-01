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

# Répertoire temporaire global pour éviter les conflits et les fuites
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "🔍 Scanning $TARGET_DIR"
echo "--------------------------------"

# Utilisation de la substitution de processus (et non d'un pipe)
# pour que les erreurs dans la boucle soient propagées au script parent.
while IFS= read -r -d '' file; do

    # Gérer les symlinks
    if [ -L "$file" ]; then
        echo "🔗 Symlink ignoré: $file"
        continue
    fi

    # Skip obvious binary files
    if ! file "$file" | grep -qiE 'text|utf|ascii'; then
        continue
    fi

    # Already valid UTF-8 ?
    if iconv -f UTF-8 -t UTF-8 "$file" -o /dev/null 2>/dev/null; then
        continue
    fi

    echo "⚠️ Converting: $file"

    tmp="$TMPDIR/$(basename "$file").tmp"
    converted=false

    # Try UTF-16 (LE & BE)
    if iconv -f UTF-16 -t UTF-8 "$file" -o "$tmp" 2>/dev/null; then
        mv "$tmp" "$file"
        echo "   ✔ Converted from UTF-16"
        converted=true
    fi

    # Try ISO-8859-1
    if [ "$converted" = false ] && iconv -f ISO-8859-1 -t UTF-8 "$file" -o "$tmp" 2>/dev/null; then
        mv "$tmp" "$file"
        echo "   ✔ Converted from ISO-8859-1"
        converted=true
    fi

    # Try Windows-1252
    if [ "$converted" = false ] && iconv -f WINDOWS-1252 -t UTF-8 "$file" -o "$tmp" 2>/dev/null; then
        mv "$tmp" "$file"
        echo "   ✔ Converted from WINDOWS-1252"
        converted=true
    fi

    # Last resort: force-clean invalid characters
    if [ "$converted" = false ] && iconv -f UTF-8 -t UTF-8 -c "$file" -o "$tmp" 2>/dev/null; then
        mv "$tmp" "$file"
        echo "   ⚠ Cleaned invalid UTF-8 characters"
        converted=true
    fi

    if [ "$converted" = false ]; then
        echo "   ❌ Could not convert: $file"
    fi

done < <(find "$TARGET_DIR" -type f -print0)

echo "--------------------------------"
echo "✅ Done"
