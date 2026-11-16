# shellcheck shell=bash
# pgos-ssh — choisir qui peut se connecter en SSH à CET ordinateur (réseau local).
# Voir : man pgos-ssh

CLE_PRIVEE="$HOME/.ssh/id_ed25519"
CLE_PUBLIQUE="$CLE_PRIVEE.pub"
AUTORISEES="$HOME/.ssh/authorized_keys"
MOI="$(id -un)"
MACHINE="$(cat /proc/sys/kernel/hostname)"
ADMIN="/etc/ssh/authorized_keys.d/$MOI"

aide() {
  cat <<EOF
pgos-ssh : choisir qui peut se connecter en SSH à cet ordinateur ($MACHINE).

  pgos-ssh ma-cle            Affiche la clé de cet ordinateur (la crée si besoin),
                             à autoriser sur l'ordinateur auquel vous voulez vous connecter.
  pgos-ssh autoriser CLÉ     Autorise une clé (une ligne « ssh-ed25519 ... »,
                             ou un fichier .pub) à se connecter à cet ordinateur.
  pgos-ssh liste             Liste les clés autorisées sur cet ordinateur.
  pgos-ssh retirer NUMÉRO    Retire une clé (numéro donné par « pgos-ssh liste »).
  pgos-ssh adresse           Indique la commande pour se connecter à cet ordinateur.

Exemple, pour aller de l'ordinateur A vers l'ordinateur B :
  1. sur A :  pgos-ssh ma-cle            (copiez la ligne affichée)
  2. sur B :  pgos-ssh autoriser <la ligne copiée>
  3. sur A :  la commande donnée par « pgos-ssh adresse » sur B

Seul le réseau local est autorisé, et uniquement par clé (jamais par mot de passe).
EOF
}

# Dossier ~/.ssh et liste des clés, avec les droits exigés par SSH.
preparer() {
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  touch "$AUTORISEES"
  chmod 600 "$AUTORISEES"
}

# Nom lisible d'une clé : son commentaire (ex. « papa@pc-salon »), sinon son type.
nom_cle() {
  awk '{ c = ""; for (i = 3; i <= NF; i++) c = c (c == "" ? "" : " ") $i; print (c == "" ? $1 " (sans nom)" : c) }' <<<"$1"
}

case "${1:-aide}" in
  ma-cle)
    if [ ! -f "$CLE_PUBLIQUE" ]; then
      echo "Création de la clé de cet ordinateur."
      echo "Une phrase de passe vous est demandée : conseillée (elle protège la clé si"
      echo "l'ordinateur est volé), ou appuyez deux fois sur Entrée pour ne pas en mettre."
      echo
      preparer
      ssh-keygen -q -t ed25519 -C "$MOI@$MACHINE" -f "$CLE_PRIVEE"
    fi
    echo
    echo "Clé de cet ordinateur (à copier en entier, c'est une seule ligne) :"
    echo
    cat "$CLE_PUBLIQUE"
    echo
    echo "Sur l'ordinateur auquel vous voulez vous connecter, tapez :"
    echo "  pgos-ssh autoriser <la ligne ci-dessus>"
    echo
    echo "Cette ligne peut être envoyée sans danger (e-mail, message, clé USB) :"
    echo "elle seule ne permet pas d'entrer. Ne transmettez jamais le fichier $CLE_PRIVEE."
    ;;

  autoriser)
    shift
    cle="$*"
    if [ -n "$cle" ] && [ -f "$cle" ]; then
      if grep -q "PRIVATE KEY" "$cle"; then
        echo "Ce fichier est une clé PRIVÉE : elle ne doit jamais être copiée ni autorisée." >&2
        echo "Sur l'autre ordinateur, utilisez « pgos-ssh ma-cle » pour obtenir sa clé publique." >&2
        exit 1
      fi
      cle="$(grep -m 1 . "$cle" || true)"
    fi
    if [ -z "$cle" ]; then
      echo "Indiquez la clé à autoriser : pgos-ssh autoriser <ligne ssh-ed25519 ...>" >&2
      exit 1
    fi
    temp="$(mktemp)"
    trap 'rm -f "$temp"' EXIT
    printf '%s\n' "$cle" >"$temp"
    if ! ssh-keygen -l -f "$temp" >/dev/null 2>&1; then
      echo "Ce n'est pas une clé SSH valide. Copiez bien toute la ligne donnée par" >&2
      echo "« pgos-ssh ma-cle » (elle commence par ssh-ed25519)." >&2
      exit 1
    fi
    preparer
    if grep -qxF "$cle" "$AUTORISEES"; then
      echo "Cette clé est déjà autorisée sur cet ordinateur."
      exit 0
    fi
    printf '%s\n' "$cle" >>"$AUTORISEES"
    echo "Clé autorisée : $(nom_cle "$cle")"
    echo
    echo "Depuis l'ordinateur qui possède cette clé, connectez-vous avec :"
    echo "  ssh $MOI@$MACHINE.local"
    ;;

  liste)
    preparer
    echo "Clés autorisées sur cet ordinateur ($MACHINE) :"
    n=0
    while IFS= read -r ligne; do
      [ -n "$ligne" ] || continue
      n=$((n + 1))
      printf '  %d) %s\n' "$n" "$(nom_cle "$ligne")"
    done <"$AUTORISEES"
    [ "$n" -gt 0 ] || echo "  (aucune)"
    if [ -s "$ADMIN" ]; then
      echo
      echo "Clés de l'administrateur PalinGoneOS (sur toutes les machines, non modifiables ici) :"
      while IFS= read -r ligne; do
        [ -n "$ligne" ] || continue
        printf '  - %s\n' "$(nom_cle "$ligne")"
      done <"$ADMIN"
    fi
    ;;

  retirer)
    numero="${2:-}"
    if ! [[ "$numero" =~ ^[0-9]+$ ]] || [ "$numero" -lt 1 ]; then
      echo "Indiquez le numéro de la clé à retirer (voir « pgos-ssh liste »)." >&2
      exit 1
    fi
    preparer
    total="$(grep -c . "$AUTORISEES" || true)"
    if [ "$numero" -gt "$total" ]; then
      echo "Il n'y a pas de clé numéro $numero (voir « pgos-ssh liste »)." >&2
      exit 1
    fi
    nom="$(grep . "$AUTORISEES" | sed -n "${numero}p")"
    temp="$(mktemp)"
    trap 'rm -f "$temp"' EXIT
    awk -v n="$numero" 'NF { c++; if (c == n) next } { print }' "$AUTORISEES" >"$temp"
    cat "$temp" >"$AUTORISEES"
    echo "Clé retirée : $(nom_cle "$nom")"
    ;;

  adresse)
    echo "Pour se connecter à cet ordinateur depuis un autre ordinateur de la maison :"
    echo "  ssh $MOI@$MACHINE.local"
    ;;

  aide | -h | --help | --aide)
    aide
    ;;

  *)
    echo "Commande inconnue : $1" >&2
    echo >&2
    aide >&2
    exit 1
    ;;
esac
