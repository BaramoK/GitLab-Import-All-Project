#!/usr/bin/env bash

set -euo pipefail

# ─── Helpers ──────────────────────────────────────────
die() { echo "$1" >&2; exit 1; }

# ─── Dépendances ──────────────────────────────────────
command -v curl >/dev/null 2>&1 || die "Erreur: curl n'est pas installé."
command -v jq >/dev/null 2>&1 || die "Erreur: jq n'est pas installé."
command -v git >/dev/null 2>&1 || die "Erreur: git n'est pas installé."

# ─── Guard clauses : validations ──────────────────────
[ -z "${1:-}" ] && die "Usage: $0 http://gitlab.compeng.fr/interop"
[ -z "${GITLAB_TOKEN:-}" ] && die "Erreur: GITLAB_TOKEN non défini"

GROUP_URL="$1"
TOKEN="$GITLAB_TOKEN"

# ─── Préparation ──────────────────────────────────────
BASE_URL=$(echo "$GROUP_URL" | awk -F/ '{print $1 "//" $3}')
GROUP_PATH=$(echo "$GROUP_URL" | sed -E 's#https?://[^/]+/##')
ENCODED_GROUP_PATH=$(echo "$GROUP_PATH" | sed 's/\//%2F/g')

# Détecter le chemin du script pour trouver convert-to-utf8.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONVERT_SCRIPT="$SCRIPT_DIR/convert-to-utf8.sh"

echo "🌍 Serveur : $BASE_URL"
echo "📦 Groupe  : $GROUP_PATH"

TMP_BODY=$(mktemp)
trap 'rm -f "$TMP_BODY"' EXIT

# ─── Pagination API ───────────────────────────────────
page=1
while true; do
    HTTP_CODE=$(curl --silent --header "PRIVATE-TOKEN: $TOKEN" \
        --output "$TMP_BODY" \
        --write-out "%{http_code}" \
        "$BASE_URL/api/v4/groups/$ENCODED_GROUP_PATH/projects?include_subgroups=true&per_page=100&page=$page")

    [ "$HTTP_CODE" != "200" ] && die "Erreur API (HTTP $HTTP_CODE): $(jq -R . \"$TMP_BODY\" 2>/dev/null || cat \"$TMP_BODY\")"

    REPO_COUNT=$(jq -r '.[].ssh_url_to_repo' "$TMP_BODY" | grep -c '^git@' || true)
    [ "$REPO_COUNT" -eq 0 ] && break

    while read -r repo; do
        echo "Clonage $repo"
        if git clone "$repo"; then
            echo "  ✅ Cloné avec succès"
            repo_dir=$(basename "$repo" .git)
            if [ -x "$CONVERT_SCRIPT" ]; then
                echo "  🔄 Conversion UTF-8 en cours pour $repo_dir..."
                "$CONVERT_SCRIPT" "$repo_dir" || echo "  ⚠️ Échec de la conversion UTF-8 pour $repo_dir" >&2
            else
                echo "  ⚠️ convert-to-utf8.sh non trouvé à $CONVERT_SCRIPT" >&2
            fi
        else
            echo "  ❌ Échec du clonage de $repo" >&2
        fi
    done < <(jq -r '.[].ssh_url_to_repo' "$TMP_BODY" | grep -v '^$')

    page=$((page + 1))
done

echo "✅ Terminé"
