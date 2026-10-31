# shellcheck shell=bash
# PalinGoneOS — installateur (mode texte, en français).
#
# Lancé automatiquement au démarrage de la clé USB (voir installer/iso.nix).
# Pour le relancer à la main : sudo palingoneos-install
#
# Étapes : Internet → choix du disque → préparation du disque → détection du matériel
#          → compte (nom affiché, identifiant, nom de la machine) → téléchargement de PalinGoneOS
#          → installation → mot de passe.

DEPOT="https://github.com/PalinGone-Master/PalinGoneOS"
CIBLE="/mnt"
LOCAL="$CIBLE/etc/palingoneos-local"
# Mémoire de secours (fichier d'échange) utilisée seulement pendant l'installation.
ECHANGE="$CIBLE/.echange-installation"

#==========================================
# Affichage
#==========================================
ENTETE="Installation de PalinGoneOS"
BILAN=() # étapes terminées, rappelées en haut de chaque écran

# Nouvel écran : on efface tout, puis en-tête souligné, bilan, et titre de l'étape.
ecran() {
  clear || true
  printf '\033[1;35m%s\n%s\033[0m\n\n' "$ENTETE" "${ENTETE//?/=}"
  if [ "${#BILAN[@]}" -gt 0 ]; then
    printf '  [OK] %s\n' "${BILAN[@]}"
    echo
  fi
  if [ -n "${1:-}" ]; then printf '\033[1m%s\033[0m\n\n' "$1"; fi
}
fait() { BILAN+=("$1"); }
info() { printf '%s\n' "$*"; }
attention() { printf '\033[1;33m%s\033[0m\n' "$*"; }
stop() {
  printf '\n\033[1;31mProblème : %s\033[0m\n' "$*" >&2
  exit 1
}
sur_erreur() { stop "l'installation s'est arrêtée à cause d'une erreur (ligne $1)."; }
annuler() {
  printf '\n\033[1;33m%s\033[0m\n' "Installation annulée : rien n'a été modifié."
  exit 1
}
pause() { read -rp "${1:-Appuyez sur Entrée pour continuer...}" _; }

# Nom affiché : lettres (accents compris), chiffres, espaces, apostrophes, points, tirets.
# (Locale UTF-8 forcée ici pour que « é » compte comme une lettre quoi qu'il arrive.)
nom_valide() {
  local LC_ALL=C.UTF-8
  [[ "$1" =~ ^[[:alnum:]\ \'._-]{1,40}$ ]]
}

# Propose un identifiant à partir du nom affiché : « Marie-José » → « marie-jose ».
# (Minuscules, accents retirés, autres caractères remplacés par des tirets.)
identifiant_depuis() {
  local -x LC_ALL=C.UTF-8 # -x : transmis aussi à sed et tr
  local s
  s="$(printf '%s' "$1" | sed -e 's/[àâäáãåÀÂÄÁÃÅ]/a/g; s/[çÇ]/c/g; s/[éèêëÉÈÊË]/e/g' \
    -e 's/[îïíìÎÏÍÌ]/i/g; s/[ôöóòõÔÖÓÒÕ]/o/g; s/[ùûüúÙÛÜÚ]/u/g; s/[ÿýŸÝ]/y/g' \
    -e 's/[ñÑ]/n/g; s/[œŒ]/oe/g; s/[æÆ]/ae/g')"
  s="$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-' '-' |
    sed -e 's/--*/-/g; s/^[-0-9]*//; s/-*$//' | cut -c1-30)"
  printf '%s' "${s:-utilisateur}"
}

# Identifiant : minuscule au début, puis minuscules, chiffres, « - » ou « _ » (31 au plus),
# et pas un nom déjà pris par le système (comptes et groupes de NixOS).
identifiant_valide() {
  [[ "$1" =~ ^[a-z][a-z0-9_-]{0,30}$ ]] || return 1
  case "$1" in
    root | admin | nixos | nobody | nogroup | users | wheel | nixbld* | systemd-* | \
      avahi | cosmic-greeter | greeter | cups | flatpak | fwupd-refresh | geoclue | messagebus | \
      nm-iodine | nm-openvpn | nscd | polkituser | qemu-libvirtd | libvirtd | rpc | rtkit | \
      wpa_supplicant | adm | audio | cdrom | clock | dialout | disk | floppy | gamemode | input | \
      keys | kmem | kvm | lp | lpadmin | networkmanager | pipewire | render | resolvconf | sgx | \
      shadow | tape | tty | utmp | uucp | video)
      return 1
      ;;
  esac
}

# Nom de machine : minuscules, chiffres et tirets (pas au début ni à la fin), 63 au plus.
machine_valide() {
  [[ "$1" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]] && [ "$1" != "localhost" ]
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

# Remplit NVIDIA_CONF (lignes NVIDIA de machine.nix, vide si aucune)
# et CARTE (phrase qui décrit la carte graphique pour l'écran).
# Entrées : $1 = sortie de « lspci -D -nn », $2 = type de châssis (DMI).
detecter_nvidia() {
  local lspci_sortie="$1" chassis="$2" cartes nv igpu puce legacy portable=0
  NVIDIA_CONF=""

  cartes="$(grep -E 'VGA compatible controller|3D controller|Display controller' <<<"$lspci_sortie" || true)"
  nv="$(grep -F '[10de:' <<<"$cartes" | head -n 1 || true)"
  if [ -z "$nv" ]; then
    CARTE="rien à installer"
    return 0
  fi

  # Nom de code de la puce, ex. « GP104 » pour une GTX 1070.
  puce="$(sed -nE 's/.*NVIDIA Corporation ([A-Z]+[0-9]+[A-Z]*).*/\1/p' <<<"$nv")"
  case "$puce" in
    GM* | GP* | GV*)
      legacy=true # GTX 9xx / 10xx (Maxwell, Pascal, Volta) : pilote 580
      ;;
    GK* | GF* | GT* | G[0-9]* | NV*)
      CARTE="NVIDIA ancienne, pilote libre"
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
    CARTE="NVIDIA de portable, pilote officiel, mode économie"
  else
    CARTE="NVIDIA, pilote officiel"
  fi
}

#==========================================
# Installation
#==========================================
main() {
  set -E
  trap 'sur_erreur $LINENO' ERR

  [ "$(id -u)" -eq 0 ] || stop "il faut lancer l'installation avec la commande : sudo palingoneos-install"
  if ! [ -d /sys/firmware/efi ]; then
    stop "la clé n'a pas démarré en mode UEFI. Redémarrez l'ordinateur et, dans le menu
           de démarrage, choisissez l'entrée de la clé qui commence par « UEFI »."
  fi

  #------------------------------------------
  ecran
  info "Bienvenue ! Cet assistant va installer PalinGoneOS sur cet ordinateur,"
  info "en 7 étapes."
  echo
  info "Avant de commencer, vérifiez que :"
  info "  - l'ordinateur est branché sur secteur ;"
  info "  - vous pouvez vous connecter à Internet (câble ou Wi-Fi) ;"
  info "  - le disque ne contient plus rien d'important : il sera entièrement effacé."
  echo
  pause "Appuyez sur Entrée pour commencer..."

  #------------------------------------------
  while ! git ls-remote --tags "$DEPOT" >/dev/null 2>&1; do
    ecran "Étape 1/7 - Connexion à Internet"
    attention "Cet ordinateur n'est pas connecté à Internet."
    echo
    info "  - Avec un câble : branchez-le, puis appuyez sur Entrée."
    info "  - En Wi-Fi : appuyez sur Entrée, choisissez votre réseau avec les"
    info "    flèches, validez avec Entrée, tapez le mot de passe du Wi-Fi,"
    info "    puis quittez avec Échap."
    echo
    pause
    nmtui connect || true
  done
  fait "Connexion à Internet"

  #------------------------------------------
  ecran "Étape 2/7 - Choix du disque"
  local usb="" source_iso disques n disque taille octets go
  source_iso="$(findmnt -no SOURCE /iso 2>/dev/null || true)"
  if [ -n "$source_iso" ]; then
    usb="$(lsblk -no PKNAME "$source_iso" 2>/dev/null | head -n 1 || true)"
  fi
  mapfile -t disques < <(lsblk -dpno NAME,TYPE | awk '$2 == "disk" { print $1 }' | grep -v -e '^/dev/zram' -e "^/dev/${usb:-AUCUN}\$" || true)
  [ "${#disques[@]}" -gt 0 ] || stop "aucun disque n'a été trouvé sur cet ordinateur."

  info "Disques trouvés (la clé USB n'apparaît pas dans la liste) :"
  for n in "${!disques[@]}"; do
    printf '  %d) %s   %s   %s\n' "$((n + 1))" "${disques[$n]}" \
      "$(lsblk -dno SIZE "${disques[$n]}" | xargs)" "$(lsblk -dno MODEL "${disques[$n]}" | xargs)"
  done
  echo
  while true; do
    read -rp "Sur quel disque installer PalinGoneOS ? Tapez son numéro : " n
    if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "${#disques[@]}" ]; then break; fi
    info "Ce numéro n'est pas dans la liste."
  done
  disque="${disques[$((n - 1))]}"
  taille="$(lsblk -dno SIZE "$disque" | xargs)"

  octets="$(lsblk -bdno SIZE "$disque" | xargs)"
  go=$((octets / 1000 / 1000 / 1000))
  [ "$go" -ge 64 ] || stop "ce disque est trop petit ($go Go). Il en faut au moins 64."
  if [ "$go" -lt 120 ]; then
    echo
    attention "Ce disque fait $go Go. C'est suffisant, mais 128 Go ou plus sont conseillés"
    attention "pour avoir de la place lors des mises à jour."
  fi

  echo
  info "Voici ce que contient actuellement $disque :"
  lsblk -o NAME,SIZE,FSTYPE,LABEL "$disque"
  echo
  attention "ATTENTION : tout ce qui se trouve sur $disque va être effacé définitivement."
  local confirmation
  read -rp "Pour confirmer, tapez EFFACER en majuscules : " confirmation
  [ "$confirmation" = "EFFACER" ] || annuler
  fait "Disque choisi : $disque ($taille)"

  #------------------------------------------
  ecran "Étape 3/7 - Préparation du disque"
  info "Préparation en cours..."
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
  [ "${#parts[@]}" -eq 2 ] || stop "le disque n'a pas pu être préparé correctement."
  boot="${parts[0]}"
  racine="${parts[1]}"
  # Attend (10 s au plus) que les deux partitions soient utilisables.
  for attente in $(seq 1 20); do
    if [ -b "$boot" ] && [ -b "$racine" ]; then break; fi
    sleep 0.5
  done
  if ! [ -b "$boot" ] || ! [ -b "$racine" ]; then
    stop "le disque n'a pas pu être préparé correctement ($attente essais)."
  fi
  mkfs.fat -F 32 -n BOOT "$boot" >/dev/null
  mkfs.ext4 -F -q -L palingoneos "$racine"
  sync

  # Fin du verrou : le système peut relire le disque, tout est déjà écrit.
  flock -u "$verrou"
  exec {verrou}<&-
  udevadm settle

  # Vérification avant d'aller plus loin.
  [ "$(blkid -p -s TYPE -o value "$racine" || true)" = "ext4" ] || stop "le disque n'a pas pu être préparé correctement ($racine)."
  [ "$(blkid -p -s TYPE -o value "$boot" || true)" = "vfat" ] || stop "le disque n'a pas pu être préparé correctement ($boot)."
  mount -t ext4 "$racine" "$CIBLE"
  mkdir -p "$CIBLE/boot"
  mount -t vfat -o fmask=0077,dmask=0077 "$boot" "$CIBLE/boot"
  fait "Disque préparé"

  #------------------------------------------
  ecran "Étape 4/7 - Détection du matériel"
  info "Détection en cours..."
  mkdir -p "$LOCAL"
  nixos-generate-config --root "$CIBLE" --show-hardware-config >"$LOCAL/hardware-configuration.nix" 2>/dev/null
  detecter_nvidia "$(lspci -D -nn)" "$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || echo 0)"
  fait "Matériel détecté"
  fait "Carte graphique : $CARTE"

  #------------------------------------------
  ecran "Étape 5/7 - Votre compte"
  local nom identifiant machine proposition
  # Nom affiché
  while true; do
    read -rp "Quel nom afficher sur l'écran de connexion ? (par exemple : Dylan, Papa) : " nom
    nom="${nom:-PalinGone}"
    if nom_valide "$nom"; then break; fi
    info "Ce nom contient un caractère non accepté. Utilisez des lettres, des chiffres,"
    info "des espaces, des apostrophes, des points ou des tirets."
  done
  # Identifiant
  proposition="$(identifiant_depuis "$nom")"
  identifiant_valide "$proposition" || proposition="utilisateur"
  echo
  info "L'identifiant est le nom technique du compte : celui du dossier personnel"
  info "(/home/...) et du terminal. En minuscules, sans accent ni espace."
  while true; do
    read -rp "Identifiant (Entrée pour garder « $proposition ») : " identifiant
    identifiant="${identifiant:-$proposition}"
    if identifiant_valide "$identifiant"; then break; fi
    info "Cet identifiant n'est pas possible. Utilisez des minuscules, des chiffres,"
    info "des tirets, en commençant par une lettre (pas de nom réservé comme « root »)."
  done
  # Nom de la machine
  proposition="pc-${identifiant//_/-}"
  proposition="${proposition:0:63}"
  echo
  info "Le nom de la machine sert à la reconnaître sur le réseau"
  info "(imprimante, partage de fichiers...)."
  while true; do
    read -rp "Nom de la machine (Entrée pour garder « $proposition ») : " machine
    machine="${machine:-$proposition}"
    if machine_valide "$machine"; then break; fi
    info "Ce nom n'est pas possible. Utilisez des minuscules, des chiffres et des tirets"
    info "(pas de tiret au début ni à la fin)."
  done
  {
    printf "# Réglages propres à CETTE machine, créés par l'installateur PalinGoneOS le %s.\n" "$(date +%d/%m/%Y)"
    printf '# Les mises à jour ne modifient jamais ce fichier.\n'
    printf '{\n'
    printf '  palingoneos.utilisateur.identifiant = "%s";   # nom du compte (terminal, /home/%s)\n' "$identifiant" "$identifiant"
    printf '  palingoneos.utilisateur.nom = "%s";   # nom affiché à la connexion\n' "$nom"
    printf '  networking.hostName = "%s";   # nom de la machine sur le réseau\n' "$machine"
    printf '%s' "$NVIDIA_CONF"
    printf '}\n'
  } >"$LOCAL/machine.nix"
  fait "Compte : $nom (identifiant : $identifiant)"
  fait "Nom de la machine : $machine"

  #------------------------------------------
  ecran "Étape 6/7 - Téléchargement de PalinGoneOS"
  info "Recherche de la dernière version..."
  local version
  git clone --quiet "$DEPOT" "$CIBLE/etc/nixos"
  version="$(git -C "$CIBLE/etc/nixos" tag --list 'v*' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1 || true)"
  [ -n "$version" ] || stop "impossible de trouver une version de PalinGoneOS à télécharger."
  git -C "$CIBLE/etc/nixos" -c advice.detachedHead=false checkout --quiet "$version"
  fait "PalinGoneOS $version téléchargé"

  #------------------------------------------
  ecran "Étape 7/7 - Installation"
  info "L'installation commence. Elle peut durer de 30 minutes à plus d'une heure,"
  info "selon la vitesse de votre connexion."
  attention "Laissez l'ordinateur allumé et branché jusqu'à la fin."
  echo
  # La configuration est lue depuis la clé USB pendant l'installation :
  # on lui montre le dossier local de la NOUVELLE machine.
  if [ -e /etc/palingoneos-local ] && [ ! -L /etc/palingoneos-local ]; then
    stop "la clé USB contient déjà un dossier /etc/palingoneos-local."
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
  fait "Logiciels installés"

  #------------------------------------------
  ecran "Mot de passe"
  info "Choisissez maintenant le mot de passe de votre compte. Il vous sera demandé"
  info "pour vous connecter et pour les réglages importants."
  info "Rien ne s'affiche pendant que vous tapez : c'est normal."
  echo
  until nixos-enter --root "$CIBLE" -c "passwd $identifiant"; do
    echo
    attention "Les deux mots de passe ne sont pas identiques. Recommencez."
    echo
  done
  fait "Mot de passe choisi"

  umount -R "$CIBLE"
  ecran "C'est terminé !"
  info "PalinGoneOS est installé."
  echo
  pause "Retirez la clé USB, puis appuyez sur Entrée : l'ordinateur va redémarrer."
  systemctl reboot
}

main "$@"
