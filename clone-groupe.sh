#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 http://gitlab.compeng.fr/interop"
  exit 1
fi

GROUP_URL="$1"
TOKEN="$GITLAB_TOKEN"

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

# Appel API
curl --silent --header "PRIVATE-TOKEN: $TOKEN" \
"$BASE_URL/api/v4/groups/$ENCODED_GROUP_PATH/projects?include_subgroups=true&per_page=100" \
| jq -r '.[].ssh_url_to_repo' \
| while read repo; do
    if [ -n "$repo" ]; then
        echo "Clonage $repo"
        git clone "$repo"
    fi
done

echo "✅ Terminé"
