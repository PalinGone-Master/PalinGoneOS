# PalinGoneOS — logiciels grand public pour les autres utilisateurs de la machine
# (navigateur, messagerie, e-mail, montage vidéo, mot de passe, sauvegarde, disques).
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

    # Partitionner et formater les disques (libre, GPL). Le mot de passe est demandé
    # à l'ouverture. withAllTools : gère aussi NTFS (Windows), exFAT (clés USB),
    # LVM, partitions chiffrées, btrfs...
    (gparted.override { withAllTools = true; })

    # Synchroniser ou monter un stockage en ligne (Google Drive, OneDrive, pCloud...).
    # Configuration : rclone config ; montage comme un dossier : rclone mount distant: ~/dossier
    rclone

    # Sons et voix (alarmes, annonces) :
    #   play fichier.wav             jouer un son (play est fourni par sox)
    #   play -n synth 1 sine 880     bip de 1 seconde à 880 Hz
    #   espeak-ng -v fr "Bonjour"    faire parler l'ordinateur
    sox
    espeak-ng
  ];
}
