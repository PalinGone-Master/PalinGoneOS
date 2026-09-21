# PalinGoneOS — recommandations NixOS : stabilité, compatibilité, disque, impression.
{ config, lib, pkgs, inputs, ... }:

{
  #==========================================
  # Nix : un seul nixpkgs, celui du système
  #==========================================
  # `nix shell nixpkgs#truc` et `nix-shell -p` utilisent la MÊME version que le système
  # (pas de nouveau téléchargement, pas de résultats différents).
  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  nix.nixPath = [ "nixpkgs=flake:nixpkgs" ];
  # Les « channels » sont l'ancienne méthode, inutile avec un flake.
  nix.channel.enable = false;

  #==========================================
  # Disque et journaux
  #==========================================
  services.fstrim.enable = true;                            # entretien hebdomadaire des SSD
  boot.tmp.cleanOnBoot = true;                              # vide /tmp à chaque démarrage
  services.journald.settings.Journal.SystemMaxUse = "500M"; # les journaux ne grossissent pas sans limite

  # Mises à jour des firmwares (BIOS, SSD, périphériques) via le service fwupd.
  services.fwupd.enable = true;

  #==========================================
  # Compatibilité logicielle
  #==========================================
  # Exécuter les programmes téléchargés hors de Nix (lanceurs de jeux, outils divers).
  programs.nix-ld.enable = true;

  # Double-clic sur un fichier .AppImage.
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  # Polices : compatibilité des documents Word/Excel dans LibreOffice.
  fonts.packages = with pkgs; [
    liberation_ttf        # équivalents métriques d'Arial, Times New Roman, Courier New
    corefonts             # polices Microsoft (Arial, Verdana…)
    noto-fonts
    noto-fonts-color-emoji
  ];

  #==========================================
  # Impression
  #==========================================
  services.printing.enable = true;
  # Les imprimantes réseau récentes sont trouvées sans pilote (IPP + Avahi).
  services.avahi.nssmdns4 = true;
  # cups-browsed est un démon réseau à l'historique de failles (2024) : inutile ici.
  services.printing.browsed.enable = false;
}
