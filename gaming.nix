# PalinGoneOS — jeux : Steam + Proton, Wine 64 bits, Lutris, Heroic, outils de performance.
{ config, lib, pkgs, ... }:

{
  programs.steam = {
    # Active aussi automatiquement les bibliothèques graphiques 32 bits
    # et les règles udev des manettes / casques VR.
    enable = true;

    # Proton-GE : version communautaire de Proton, souvent plus compatible que celle de Valve.
    # Il apparaît dans Steam > Propriétés du jeu > Compatibilité.
    extraCompatPackages = [ pkgs.proton-ge-bin ];

    # Correctifs (winetricks) pour les jeux Proton récalcitrants.
    protontricks.enable = true;

    # Steam Input (manettes, clavier/souris émulés) sous Wayland (COSMIC).
    extest.enable = true;

    # Ports RÉSEAU FERMÉS par défaut. À mettre à true seulement si vous utilisez
    # Steam Link / Remote Play, les parties en réseau local ou un serveur dédié.
    remotePlay.openFirewall = false;
    localNetworkGameTransfers.openFirewall = false;
    dedicatedServer.openFirewall = false;
  };

  # Optimise le processeur pendant une partie (à lancer avec : gamemoderun %command%).
  programs.gamemode.enable = true;
  # Micro-compositeur pour les jeux (mise à l'échelle, FSR). Usage : gamescope -- %command%
  programs.gamescope.enable = true;

  # gamemode exige d'appartenir à ce groupe (à ajouter aussi aux futurs comptes créés par l'ISO).
  users.users.palingone.extraGroups = [ "gamemode" ];

  environment.systemPackages = with pkgs; [
    lutris                     # lanceur multi-plateformes (Battle.net, EA, GOG, émulateurs…)
    heroic                     # Epic Games, GOG, Amazon Games
    mangohud                   # affichage FPS / températures (mangohud %command%)
    wineWow64Packages.stable   # Wine 32 ET 64 bits (l'ancien « wine » était 32 bits seulement)
    winetricks
    vulkan-tools               # diagnostic graphique : vulkaninfo, vkcube
  ];
}
