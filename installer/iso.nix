# PalinGoneOS — clé USB d'installation.
#
# Construire l'image (depuis le dossier du dépôt) :   nix build .#iso
# Résultat :                                          result/iso/PalinGoneOS-installateur.iso
#
# Base : l'ISO « minimale » officielle de NixOS (mode texte), en français,
# qui lance automatiquement l'installateur palingoneos-install au démarrage.
# L'ISO ne contient PAS PalinGoneOS : l'installateur télécharge toujours la
# dernière version publiée sur GitHub. Inutile donc de la refaire à chaque version.
{ config, lib, pkgs, modulesPath, ... }:

let
  installateur = pkgs.writeShellApplication {
    name = "palingoneos-install";
    runtimeInputs = [
      pkgs.git
      pkgs.pciutils # lspci : détection de la carte graphique
      pkgs.util-linux # lsblk, sfdisk, wipefs, findmnt
      pkgs.dosfstools # mkfs.fat
      pkgs.e2fsprogs # mkfs.ext4
      pkgs.lvm2 # dmsetup : libérer les volumes LVM et chiffrés d'un ancien système
      pkgs.gawk
      pkgs.gnused
      pkgs.coreutils
      pkgs.networkmanager # nmtui (Wi-Fi)
      config.systemd.package # udevadm, systemctl
      config.system.build.nixos-install
      config.system.build.nixos-generate-config
      pkgs.nixos-enter
    ];
    text = builtins.readFile ./palingoneos-install.sh;
  };

  # Thème du menu de démarrage (GRUB) aux couleurs de PalinGoneOS.
  # Les images et theme.txt sont dans installer/grub-theme/ ; les polices sont
  # fabriquées ici, à partir de DejaVu Sans (GRUB a besoin de son propre format .pf2).
  themeGrub = pkgs.runCommand "palingoneos-grub-theme" { nativeBuildInputs = [ pkgs.grub2 ]; } ''
    mkdir -p $out
    cp ${./grub-theme}/* $out/
    polices=${pkgs.dejavu_fonts}/share/fonts/truetype
    grub-mkfont -s 24 -o $out/dejavu-sans-24.pf2 $polices/DejaVuSans.ttf
    grub-mkfont -s 20 -o $out/dejavu-sans-20.pf2 $polices/DejaVuSans.ttf
    grub-mkfont -s 24 -o $out/dejavu-sans-bold-24.pf2 $polices/DejaVuSans-Bold.ttf
  '';
in
{
  imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # Nom du fichier et de la clé.
  image.baseName = lib.mkForce "PalinGoneOS-installateur";
  isoImage.volumeID = "PALINGONEOS_INSTALL";
  # Menu de démarrage : thème PalinGoneOS, entrée principale « Installer PalinGoneOS ».
  isoImage.grubTheme = themeGrub;
  isoImage.prependToMenuLabel = "Installer ";
  isoImage.appendToMenuLabel = lib.mkForce "";
  system.nixos.distroName = "PalinGoneOS";
  system.nixos.label = "";
  # Compression plus rapide à construire (l'image est un peu plus grosse).
  isoImage.squashfsCompression = "zstd -Xcompression-level 6";

  # Français : clavier AZERTY dès le démarrage, messages en français.
  console.keyMap = "fr";
  i18n.defaultLocale = "fr_FR.UTF-8";
  time.timeZone = "Europe/Paris";

  # Pas d'accès à distance sur la clé (inutile, et les comptes n'ont pas de mot de passe).
  services.openssh.enable = lib.mkForce false;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages = [ installateur pkgs.git pkgs.pciutils ];

  # Message affiché au-dessus de l'invite de connexion.
  services.getty.helpLine = lib.mkForce ''
    Installation de PalinGoneOS : elle démarre toute seule.
    Pour la relancer : sudo palingoneos-install
    Pour se connecter au Wi-Fi : nmtui
  '';

  # Lance l'installateur automatiquement sur le premier écran, une seule fois.
  programs.bash.loginShellInit = ''
    if [ "$(tty)" = /dev/tty1 ] && [ -z "''${PGOS_INSTALL_LANCE:-}" ]; then
      export PGOS_INSTALL_LANCE=1
      sudo palingoneos-install || echo "Pour recommencer l'installation, tapez : sudo palingoneos-install"
    fi
  '';
}
