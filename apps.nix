# PalinGoneOS — logiciels grand public pour les autres utilisateurs de la machine
# (messagerie, e-mail, montage vidéo, mot de passe, sauvegarde).
#
# Chrome reste installé en Flatpak par choix : il n'est pas listé ici.
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    thunderbird  # client e-mail
    discord      # messagerie (propriétaire, aucune alternative libre n'existe)
    karere       # client WhatsApp Web, léger et libre (GPLv3)
    kdePackages.kdenlive   # montage vidéo (KDE)
    keepassxc    # gestionnaire de mots de passe, libre (GPLv2+)
    deja-dup     # sauvegarde de fichiers, libre (GPL) — interface simple, planification incluse
    vlc          # lecteur vidéo, tous formats/codecs, libre (LGPL) — coexiste avec cosmic-player
  ];
}
