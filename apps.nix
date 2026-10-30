# PalinGoneOS — logiciels grand public pour les autres utilisateurs de la machine
# (navigateur, messagerie, e-mail, montage vidéo, mot de passe, sauvegarde).
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Navigateur. Installé par Nix (et non plus en Flatpak) pour pouvoir créer des
    # web apps : en Flatpak, Chrome n'a pas le droit d'écrire leurs raccourcis.
    # Les raccourcis créés appellent « google-chrome-stable » (nom fixe) : ils
    # continuent de fonctionner après chaque mise à jour.
    # --ozone-platform-hint=auto : affichage Wayland natif sous COSMIC (texte plus net).
    (google-chrome.override { commandLineArgs = "--ozone-platform-hint=auto"; })

    thunderbird  # client e-mail
    discord      # messagerie (propriétaire, aucune alternative libre n'existe)
    karere       # client WhatsApp Web, léger et libre (GPLv3)
    kdePackages.kdenlive   # montage vidéo (KDE)
    keepassxc    # gestionnaire de mots de passe, libre (GPLv2+)
    deja-dup     # sauvegarde de fichiers, libre (GPL) — interface simple, planification incluse
    vlc          # lecteur vidéo, tous formats/codecs, libre (LGPL) — coexiste avec cosmic-player
  ];
}
