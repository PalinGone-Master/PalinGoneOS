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

    # Comptes en ligne (Google Drive, OneDrive, pCloud...) : rclone, et Rclone UI pour
    # les ajouter en cliquant (libre, Apache 2.0 ; version gratuite : 4 comptes).
    # Chaque compte s'ouvre ensuite tout seul dans ~/Cloud/<nom> (voir cloud.nix).
    rclone
    # Rclone UI, avec l'affichage corrigé : sous COSMIC (Wayland), son moteur d'affichage
    # WebKitGTK donne sinon des fenêtres noires. Simple enveloppe : rien n'est recompilé.
    (symlinkJoin {
      name = "rclone-ui-palingoneos";
      paths = [ rclone-ui ];
      nativeBuildInputs = [ makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/rclone-ui \
          --set WEBKIT_DISABLE_DMABUF_RENDERER 1 \
          --set WEBKIT_DISABLE_COMPOSITING_MODE 1
      '';
    })
  ];
}
