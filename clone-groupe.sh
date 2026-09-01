#!/usr/bin/env bash

set -euo pipefail

# Vérification des dépendances
command -v curl >/dev/null 2>&1 || { echo "Erreur: curl n'est pas installé." >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "Erreur: jq n'est pas installé." >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "Erreur: git n'est pas installé." >&2; exit 1; }

if [ -z "${1:-}" ]; then
  echo "Usage: $0 http://gitlab.compeng.fr/interop"
  exit 1
fi

GROUP_URL="$1"
TOKEN="${GITLAB_TOKEN:-}"

if [ -z "$TOKEN" ]; then
  echo "Erreur: GITLAB_TOKEN non défini"
  exit 1
fi

# Extraire base URL (protocole + domaine)
BASE_URL=$(echo "$GROUP_URL" | awk -F/ '{print $1 "//" $3}')

# Extraire chemin du groupe
GROUP_PATH=$(echo "$GROUP_URL" | sed -E 's#https?://[^/]+/##')

# Encoder les slashs pour l'API (%2F)
ENCODED_GROUP_PATH=$(echo "$GROUP_PATH" | sed 's/\//%2F/g')

echo "🌍 Serveur : $BASE_URL"
echo "📦 Groupe  : $GROUP_PATH"

# Fichiers temporaires pour les réponses API
TMP_BODY=$(mktemp)
trap 'rm -f "$TMP_BODY"' EXIT

PAGE=1
while true; do
  # Appel API avec récupération du code HTTP
  HTTP_CODE=$(curl --silent --header "PRIVATE-TOKEN: $TOKEN" \
    --output "$TMP_BODY" \
    --write-out "%{http_code}" \
    "$BASE_URL/api/v4/groups/$ENCODED_GROUP_PATH/projects?include_subgroups=true&per_page=100&page=$PAGE")

  if [ "$HTTP_CODE" != "200" ]; then
    echo "Erreur API (HTTP $HTTP_CODE):" >&2
    jq -R . "$TMP_BODY" 2>/dev/null || cat "$TMP_BODY" >&2
    exit 1
  fi

  # Vérifier si la page contient des dépôts
  REPO_COUNT=$(jq -r '.[].ssh_url_to_repo' "$TMP_BODY" | grep -c '^git@' || true)

  if [ "$REPO_COUNT" -eq 0 ]; then
    break
  fi

  jq -r '.[].ssh_url_to_repo' "$TMP_BODY" | while read -r repo; do
    if [ -n "$repo" ]; then
      echo "Clonage $repo"
      if git clone "$repo"; then
        echo "  ✅ Cloné avec succès"
      else
        echo "  ❌ Échec du clonage de $repo" >&2
      fi
    fi
  done

  PAGE=$((PAGE + 1))
done

echo "✅ Terminé"
