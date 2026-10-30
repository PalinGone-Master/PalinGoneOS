#!/usr/bin/env bash
# PalinGoneOS — monte le dernier chiffre de la version dans configuration.nix
# (ex. 0.31.25 → 0.31.26) et affiche la nouvelle version.
# Utilisé par la mise à jour automatique (.github/workflows/maj-nixpkgs.yml).
set -euo pipefail

fichier="${1:-configuration.nix}"
commentaire="${2:-mise à jour automatique des logiciels}"

actuelle="$(sed -nE 's/^ *palingoneos\.version = "([0-9]+\.[0-9]+\.[0-9]+)";.*/\1/p' "$fichier")"
if ! [[ "$actuelle" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version introuvable dans $fichier" >&2
  exit 1
fi

IFS=. read -r majeur mineur correctif <<<"$actuelle"
nouvelle="$majeur.$mineur.$((correctif + 1))"

sed -i -E "s|^( *)palingoneos\.version = \"$actuelle\";.*|\1palingoneos.version = \"$nouvelle\";   # $commentaire|" "$fichier"
grep -q "palingoneos.version = \"$nouvelle\";" "$fichier" || {
  echo "La version n'a pas pu être modifiée" >&2
  exit 1
}
echo "$nouvelle"
