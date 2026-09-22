# Configuration principale de PalinGoneOS.
# Aide : `man configuration.nix`, https://search.nixos.org/options et `nixos-help`.

#========================================================================================================
#                                            PalinGoneOS
#========================================================================================================

{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix   # propre à chaque machine
    ./palingoneos-update.nix       # service de mise à jour (polkit)
    ./branding.nix                 # nom, version, fond d'écran, démarrage, fastfetch
    ./gaming.nix                   # Steam, Proton, Wine, Lutris, Heroic
    ./remote.nix                   # Remmina, RustDesk
    ./system-tuning.nix            # recommandations NixOS (disque, impression, compatibilité)
    ./dev-tools.nix                # outils de développement (machine du créateur seulement)
    ./apps.nix			   # logiciels grand public (Thunderbird, Discord, WhatsApp, Kdenlive...)
  ];

  #==============================================================================================================================
  # VERSION — le SEUL endroit à modifier pour publier une nouvelle version (doit correspondre au tag Git vX.Y.Z)
  #==============================================================================================================================
  palingoneos.version = "0.31.8";

  # Activation de Nix Experimental
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Nettoyage automatique : sans ça, le disque se remplit à chaque mise à jour.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nix.optimise.automatic = true;

  # Activation "Maximiser et minimiser" GTK 3+4
  systemd.user.services.palingoneos-dconf-buttons = {
    description = "PalinGoneOS - GTK window buttons";

    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.dconf}/bin/dconf write /org/gnome/desktop/wm/preferences/button-layout \"':minimize,maximize,close'\"";
    };
  };

  # Paquet Non Libre (Steam, etc.)
  nixpkgs.config.allowUnfree = true;

  #==========================================
  # Démarrage
  #==========================================
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 8;

  #==========================================
  # Matériel
  #==========================================
  hardware.graphics.enable = true;
  # Pilotes/firmwares propriétaires redistribuables (Wi-Fi, Bluetooth… sur vraie machine).
  hardware.enableRedistributableFirmware = true;
  # Swap compressé en RAM (aucun swap n'est défini sur le disque).
  zramSwap.enable = true;

  #==========================================
  # Réseau et sécurité
  #==========================================
  networking.hostName = "palingoneos";
  networking.networkmanager.enable = true;

  # Pare-feu actif : aucun port entrant n'est ouvert.
  # Backend nftables : le successeur moderne d'iptables (règles plus rapides et plus lisibles).
  networking.nftables.enable = true;
  networking.firewall.enable = true;

  # SSH DÉSACTIVÉ : il n'est pas utile sur un poste familial et exposait le compte utilisateur.
  # Pour le réactiver, utiliser UNIQUEMENT des clés (jamais de mot de passe) :
  #   services.openssh.enable = true;
  #   services.openssh.settings.PasswordAuthentication = false;
  #   services.openssh.settings.PermitRootLogin = "no";
  services.openssh.enable = false;

  # sudo : mot de passe obligatoire, réservé au groupe wheel.
  # (La mise à jour du système passe par palingoneos-update.nix, sans règle NOPASSWD.)
  security.sudo.wheelNeedsPassword = true;
  security.sudo.execWheelOnly = true;
  security.polkit.enable = true;

  #==========================================
  # Langue, heure, clavier
  #==========================================
  time.timeZone = "Europe/Paris";

  i18n.defaultLocale = "fr_FR.UTF-8";
  console.keyMap = "fr";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "fr_FR.UTF-8";
    LC_IDENTIFICATION = "fr_FR.UTF-8";
    LC_MEASUREMENT = "fr_FR.UTF-8";
    LC_MONETARY = "fr_FR.UTF-8";
    LC_NAME = "fr_FR.UTF-8";
    LC_NUMERIC = "fr_FR.UTF-8";
    LC_PAPER = "fr_FR.UTF-8";
    LC_TELEPHONE = "fr_FR.UTF-8";
    LC_TIME = "fr_FR.UTF-8";
  };
  services.xserver.xkb.layout = "fr";

  #==========================================
  # Utilisateur
  #==========================================
  # Aucun mot de passe dans ce fichier : le dépôt est PUBLIC.
  # Le mot de passe se change avec la commande `passwd`.
  users.users.palingone = {
    isNormalUser = true;
    description = "PalinGone";
    extraGroups = [ "wheel" "networkmanager" ];
  };

  # Définition propre du shell par défaut pour tous les futurs utilisateurs de votre OS
  users.defaultUserShell = pkgs.bash;

  # Inscription globale et pérenne des chemins dynamiques et statiques dans /etc/shells
  environment.shells = [
    pkgs.bash
    "/run/current-system/sw/bin/bash"
    "/run/current-system/sw/bin/sh"
  ];

  #==========================================
  # Applications
  #==========================================
  # Navigateur.
  programs.firefox = {
    enable = true;
    languagePacks = [ "fr" ];
    policies = {
      RequestedLocales = [ "fr" ];
    };
    preferences = {
      "browser.nova.enabled" = true;
    };
  };

  environment.systemPackages = with pkgs; [
    # Système de base
    vim
    nano
    wget
    curl
    git
    htop
    fastfetch
    gsettings-desktop-schemas

    # L'updater de PalinGoneOS
    inputs.palingoneos-updater.packages.${pkgs.stdenv.hostPlatform.system}.palin-gone-os-updater

    # Suite Bureautique
    libreoffice

    # Magasin d'applications COSMIC
    cosmic-store
  ];

  # COSMIC Desktop
  services.displayManager.cosmic-greeter.enable = true;
  services.desktopManager.cosmic.enable = true;

  # ==========================
  # FLATPAK / FLATHUB
  # ==========================
  services.flatpak.enable = true;

  # Dépôts Flatpak PalinGoneOS
  services.flatpak.remotes = [
    # Flathub
    {
      name = "flathub";
      location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
    }
    # Applets COSMIC
    {
      name = "cosmic";
      location = "https://apt.pop-os.org/cosmic/cosmic.flatpakrepo";
    }
  ];

  # Version de compatibilité des données : NE JAMAIS la modifier après l'installation.
  system.stateVersion = "26.05";
}
