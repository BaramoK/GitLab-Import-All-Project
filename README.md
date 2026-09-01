# GitLab Import All Project

Scripts utilitaires pour importer des projets GitLab et convertir des encodages de fichiers.

## Dépendances

- `bash`
- `curl`
- `jq`
- `git`
- `iconv`
- `file`
- `find`
- `mktemp`

## Scripts

### `clone-groupe.sh`

Clone tous les dépôts d'un groupe GitLab (y compris les sous-groupes) via l'API v4.

```bash
export GITLAB_TOKEN="votre_token"
./clone-groupe.sh https://gitlab.example.com/mon-groupe
```

**Fonctionnalités :**
- Vérification des dépendances (`curl`, `jq`, `git`)
- Gestion des erreurs HTTP
- Pagination automatique (gère plus de 100 projets)
- Rapport de succès/échec par dépôt

### `convert-to-utf8.sh`

Convertit récursivement les fichiers texte d'un répertoire en UTF-8.

```bash
./convert-to-utf8.sh /chemin/vers/repertoire
```

**Fonctionnalités :**
- Détection automatique de l'encodage source (UTF-16, ISO-8859-1, WINDOWS-1252)
- Nettoyage des caractères invalides en dernier recours
- Ignorance des fichiers binaires et des symlinks
- Gestion sécurisée des fichiers temporaires

## Licence

GNU General Public License v3.0 — voir le fichier [LICENSE](LICENSE).
