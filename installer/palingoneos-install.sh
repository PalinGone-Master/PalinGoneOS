# shellcheck shell=bash
# PalinGoneOS — installateur (mode texte, en français).
#
# Lancé automatiquement au démarrage de la clé USB (voir installer/iso.nix).
# Pour le relancer à la main : sudo palingoneos-install
#
# Étapes : Internet → choix du disque → préparation du disque → détection du matériel
#          → nom de l'utilisateur → téléchargement de PalinGoneOS → installation → mot de passe.

DEPOT="https://github.com/PalinGone-Master/PalinGoneOS"
CIBLE="/mnt"
LOCAL="$CIBLE/etc/palingoneos-local"
# Mémoire de secours (fichier d'échange) utilisée seulement pendant l'installation.
ECHANGE="$CIBLE/.echange-installation"

#==========================================
# Affichage
#==========================================
titre() { printf '\n\033[1;35m=== %s ===\033[0m\n\n' "$*"; }
info() { printf '%s\n' "$*"; }
attention() { printf '\033[1;33m%s\033[0m\n' "$*"; }
stop() {
  printf '\n\033[1;31mERREUR : %s\033[0m\n' "$*" >&2
  exit 1
}
pause() { read -rp "Appuyez sur Entrée pour continuer… " _; }

# Nom affiché : lettres (accents compris), chiffres, espaces, apostrophes, points, tirets.
# (Locale UTF-8 forcée ici pour que « é » compte comme une lettre quoi qu'il arrive.)
nom_valide() {
  local LC_ALL=C.UTF-8
  [[ "$1" =~ ^[[:alnum:]\ \'._-]{1,40}$ ]]
}

#==========================================
# Matériel
#==========================================

# "0000:01:00.0 VGA compatible controller..." → "PCI:1@0:0:0"
# (lspci donne l'adresse en hexadécimal, NixOS la veut en décimal).
bus_id() {
  local adr="${1%% *}" dom bus dev fn
  dom="${adr%%:*}"
  adr="${adr#*:}"
  bus="${adr%%:*}"
  adr="${adr#*:}"
  dev="${adr%%.*}"
  fn="${adr#*.}"
  printf 'PCI:%d@%d:%d:%d' "$((16#$bus))" "$((16#$dom))" "$((16#$dev))" "$((16#$fn))"
}

# Écrit dans la variable NVIDIA_CONF les lignes NVIDIA de machine.nix (vide si aucune).
# Entrées : $1 = sortie de « lspci -D -nn », $2 = type de châssis (DMI).
detecter_nvidia() {
  local lspci_sortie="$1" chassis="$2" cartes nv igpu puce legacy portable=0
  NVIDIA_CONF=""

  cartes="$(grep -E 'VGA compatible controller|3D controller|Display controller' <<<"$lspci_sortie" || true)"
  nv="$(grep -F '[10de:' <<<"$cartes" | head -n 1 || true)"
  if [ -z "$nv" ]; then
    info "Carte graphique : pas de NVIDIA → pilotes libres (Mesa), rien à régler."
    return 0
  fi

  # Nom de code de la puce, ex. « GP104 » pour une GTX 1070.
  puce="$(sed -nE 's/.*NVIDIA Corporation ([A-Z]+[0-9]+[A-Z]*).*/\1/p' <<<"$nv")"
  case "$puce" in
    GM* | GP* | GV*)
      legacy=true # GTX 9xx / 10xx (Maxwell, Pascal, Volta) : pilote 580
      ;;
    GK* | GF* | GT* | G[0-9]* | NV*)
      attention "Carte NVIDIA trop ancienne pour le pilote NVIDIA actuel ($puce) :"
      attention "le pilote libre (nouveau) sera utilisé."
      return 0
      ;;
    *)
      legacy=false # RTX, GTX 16xx et plus récentes (ou carte trop récente pour être connue)
      ;;
  esac

  # Portable : types de châssis DMI 8, 9, 10, 14, 31, 32.
  case "$chassis" in 8 | 9 | 10 | 14 | 31 | 32) portable=1 ;; esac
  igpu="$(grep -E '\[(8086|1002):' <<<"$cartes" | head -n 1 || true)"

  NVIDIA_CONF="  palingoneos.nvidia.enable = true;   # carte NVIDIA détectée : ${puce:-modèle récent}
  palingoneos.nvidia.legacy = ${legacy};   # true = pilote 580 (GTX 9xx/10xx)
"
  if [ "$portable" = 1 ] && [ -n "$igpu" ]; then
    NVIDIA_CONF+="  palingoneos.nvidia.prime.enable = true;   # portable à deux puces graphiques
  palingoneos.nvidia.prime.nvidiaBusId = \"$(bus_id "$nv")\";
"
    if grep -qF '[8086:' <<<"$igpu"; then
      NVIDIA_CONF+="  palingoneos.nvidia.prime.intelBusId = \"$(bus_id "$igpu")\";
"
    else
      NVIDIA_CONF+="  palingoneos.nvidia.prime.amdgpuBusId = \"$(bus_id "$igpu")\";
"
    fi
    info "Carte graphique : NVIDIA $puce + puce intégrée (portable) → pilote NVIDIA, mode économie (PRIME)."
  else
    info "Carte graphique : NVIDIA ${puce:-récente} → pilote NVIDIA."
  fi
}

#==========================================
# Installation
#==========================================
main() {
  set -E
  trap 'stop "une étape a échoué (ligne $LINENO). Relancez avec : sudo palingoneos-install"' ERR

  [ "$(id -u)" -eq 0 ] || stop "lancez l'installateur avec : sudo palingoneos-install"
  [ -d /sys/firmware/efi ] || stop "la clé USB n'a pas démarré en mode UEFI. Redémarrez et choisissez l'entrée « UEFI » de la clé dans le menu de démarrage."

  clear || true
  titre "Installation de PalinGoneOS"
  info "Cet assistant installe PalinGoneOS sur cet ordinateur."
  info "Il faut : une connexion à Internet, et un disque d'au moins 64 Go qui sera ENTIÈREMENT effacé."
  pause

  #------------------------------------------
  titre "Étape 1/7 — Connexion à Internet"
  while ! git ls-remote --tags "$DEPOT" >/dev/null 2>&1; do
    attention "Pas d'accès à Internet."
    info "- Câble Ethernet : branchez-le, puis appuyez sur Entrée."
    info "- Wi-Fi : une fenêtre va s'ouvrir. Choisissez votre réseau avec les flèches, Entrée,"
    info "  tapez le mot de passe du Wi-Fi, puis allez sur « Quitter » (Échap)."
    pause
    nmtui connect || true
  done
  info "Connexion à Internet : OK."

  #------------------------------------------
  titre "Étape 2/7 — Choix du disque"
  local usb="" source_iso disques n disque octets go
  source_iso="$(findmnt -no SOURCE /iso 2>/dev/null || true)"
  if [ -n "$source_iso" ]; then
    usb="$(lsblk -no PKNAME "$source_iso" 2>/dev/null | head -n 1 || true)"
  fi
  mapfile -t disques < <(lsblk -dpno NAME,TYPE | awk '$2 == "disk" { print $1 }' | grep -v -e '^/dev/zram' -e "^/dev/${usb:-AUCUN}\$" || true)
  [ "${#disques[@]}" -gt 0 ] || stop "aucun disque trouvé."

  info "Disques disponibles (la clé USB d'installation n'est pas proposée) :"
  for n in "${!disques[@]}"; do
    printf '  %d) %s   %s   %s\n' "$((n + 1))" "${disques[$n]}" \
      "$(lsblk -dno SIZE "${disques[$n]}" | xargs)" "$(lsblk -dno MODEL "${disques[$n]}" | xargs)"
  done
  while true; do
    read -rp "Numéro du disque où installer PalinGoneOS : " n
    if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "${#disques[@]}" ]; then break; fi
    info "Tapez un des numéros de la liste."
  done
  disque="${disques[$((n - 1))]}"

  octets="$(lsblk -bdno SIZE "$disque" | xargs)"
  go=$((octets / 1000 / 1000 / 1000))
  [ "$go" -ge 64 ] || stop "ce disque est trop petit ($go Go). Il faut au moins 64 Go."
  if [ "$go" -lt 120 ]; then
    attention "Disque de $go Go : ça fonctionne, mais 128 Go ou plus sont conseillés (place pour les mises à jour)."
  fi

  echo
  info "Contenu actuel de $disque :"
  lsblk -o NAME,SIZE,FSTYPE,LABEL "$disque"
  echo
  attention "ATTENTION : TOUT le contenu de $disque va être EFFACÉ, définitivement."
  local confirmation
  read -rp "Pour confirmer, tapez EFFACER (en majuscules) : " confirmation
  [ "$confirmation" = "EFFACER" ] || stop "installation annulée. Rien n'a été modifié."

  #------------------------------------------
  titre "Étape 3/7 — Préparation du disque"
  local p parts boot racine verrou attente
  swapoff "$ECHANGE" 2>/dev/null || true # reste d'un essai précédent
  umount -R "$CIBLE" 2>/dev/null || true
  for p in $(lsblk -lnpo NAME "$disque" | tail -n +2); do
    umount "$p" 2>/dev/null || true
    swapoff "$p" 2>/dev/null || true
  done
  udevadm settle

  # VERROU sur le disque pendant le découpage et le formatage.
  # Sans lui, le système (udev) relit le disque en arrière-plan juste après le
  # découpage, recrée les partitions… et peut effacer le formatage en cours.
  # Avec le verrou, il attend qu'on ait fini.
  exec {verrou}<"$disque"
  flock -x "$verrou"

  wipefs -af "$disque" >/dev/null
  # Table GPT : 1 Go pour le démarrage (UEFI), le reste pour le système.
  sfdisk --quiet --wipe always "$disque" <<'EOF'
label: gpt
size=1GiB, type=U, name="BOOT"
type=L, name="PALINGONEOS"
EOF
  partx -u "$disque" 2>/dev/null || true # fait relire la nouvelle table au noyau
  mapfile -t parts < <(lsblk -lnpo NAME,TYPE "$disque" | awk '$2 == "part" { print $1 }')
  [ "${#parts[@]}" -eq 2 ] || stop "le disque n'a pas été découpé comme prévu."
  boot="${parts[0]}"
  racine="${parts[1]}"
  # Attend (10 s au plus) que les deux partitions soient utilisables.
  for attente in $(seq 1 20); do
    if [ -b "$boot" ] && [ -b "$racine" ]; then break; fi
    sleep 0.5
  done
  if ! [ -b "$boot" ] || ! [ -b "$racine" ]; then
    stop "les partitions ne sont pas apparues ($attente essais)."
  fi
  mkfs.fat -F 32 -n BOOT "$boot" >/dev/null
  mkfs.ext4 -F -q -L palingoneos "$racine"
  sync

  # Fin du verrou : le système peut relire le disque, tout est déjà écrit.
  flock -u "$verrou"
  exec {verrou}<&-
  udevadm settle

  # Vérification avant d'aller plus loin.
  [ "$(blkid -p -s TYPE -o value "$racine" || true)" = "ext4" ] || stop "le formatage de $racine n'a pas tenu."
  [ "$(blkid -p -s TYPE -o value "$boot" || true)" = "vfat" ] || stop "le formatage de $boot n'a pas tenu."
  mount -t ext4 "$racine" "$CIBLE"
  mkdir -p "$CIBLE/boot"
  mount -t vfat -o fmask=0077,dmask=0077 "$boot" "$CIBLE/boot"
  info "Disque prêt : $boot (démarrage) et $racine (système)."

  #------------------------------------------
  titre "Étape 4/7 — Détection du matériel"
  mkdir -p "$LOCAL"
  nixos-generate-config --root "$CIBLE" --show-hardware-config >"$LOCAL/hardware-configuration.nix" 2>/dev/null
  info "Fichier matériel créé : /etc/palingoneos-local/hardware-configuration.nix"
  detecter_nvidia "$(lspci -D -nn)" "$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || echo 0)"

  #------------------------------------------
  titre "Étape 5/7 — Nom de l'utilisateur"
  local nom
  while true; do
    read -rp "Nom affiché sur l'écran de connexion (ex. : Papa, Marie) : " nom
    nom="${nom:-PalinGone}"
    if nom_valide "$nom"; then break; fi
    info "Utilisez seulement des lettres, chiffres, espaces, apostrophes, points ou tirets."
  done
  {
    printf "# Réglages propres à CETTE machine, créés par l'installateur PalinGoneOS le %s.\n" "$(date +%d/%m/%Y)"
    printf '# Les mises à jour ne modifient jamais ce fichier.\n'
    printf '{\n'
    printf '  users.users.palingone.description = "%s";   # nom affiché à la connexion\n' "$nom"
    printf '%s' "$NVIDIA_CONF"
    printf '}\n'
  } >"$LOCAL/machine.nix"
  info "Réglages de la machine enregistrés : /etc/palingoneos-local/machine.nix"

  #------------------------------------------
  titre "Étape 6/7 — Téléchargement de PalinGoneOS"
  local version
  git clone --quiet "$DEPOT" "$CIBLE/etc/nixos"
  version="$(git -C "$CIBLE/etc/nixos" tag --list 'v*' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1 || true)"
  [ -n "$version" ] || stop "aucune version publiée de PalinGoneOS n'a été trouvée."
  git -C "$CIBLE/etc/nixos" -c advice.detachedHead=false checkout --quiet "$version"
  info "Version : $version"

  #------------------------------------------
  titre "Étape 7/7 — Installation"
  info "Téléchargement et installation de tous les logiciels."
  info "Comptez de 30 minutes à plus d'une heure selon la connexion. Ne pas éteindre."
  echo
  # La configuration est lue depuis la clé USB pendant l'installation :
  # on lui montre le dossier local de la NOUVELLE machine.
  if [ -e /etc/palingoneos-local ] && [ ! -L /etc/palingoneos-local ]; then
    stop "/etc/palingoneos-local existe déjà sur la clé USB."
  fi
  ln -sfn "$LOCAL" /etc/palingoneos-local
  # Mémoire de secours : Nix a besoin de plus de 4 Go de mémoire pour installer
  # PalinGoneOS. Sans elle, sur un ordinateur avec peu de RAM, Linux arrête Nix
  # en plein milieu (« Out of memory »). Fichier de 8 Go sur le nouveau disque,
  # créé APRÈS la détection du matériel (sinon il serait noté dans la configuration)
  # et supprimé à la fin.
  if [ ! -e "$ECHANGE" ]; then
    fallocate -l 8G "$ECHANGE"
    chmod 600 "$ECHANGE"
    mkswap "$ECHANGE" >/dev/null
  fi
  swapon "$ECHANGE"
  nixos-install --impure --no-root-passwd --no-channel-copy --flake "$CIBLE/etc/nixos#palingoneos"
  swapoff "$ECHANGE"
  rm -f "$ECHANGE" /etc/palingoneos-local

  #------------------------------------------
  titre "Mot de passe"
  info "Choisissez le mot de passe du compte. Il sera demandé à la connexion"
  info "et pour les opérations d'administration. (Rien ne s'affiche pendant la saisie, c'est normal.)"
  until nixos-enter --root "$CIBLE" -c 'passwd palingone'; do
    attention "Les deux saisies ne correspondent pas, recommencez."
  done

  umount -R "$CIBLE"
  titre "Installation terminée !"
  info "Retirez la clé USB, puis appuyez sur Entrée pour redémarrer sur PalinGoneOS."
  pause
  systemctl reboot
}

main "$@"
