# PalinGoneOS — pilote propriétaire NVIDIA, ÉTEINT par défaut.
#
# Il ne s'allume QUE sur les machines qui le demandent, dans leur fichier local
# /etc/palingoneos-local/machine.nix (voir local.nix). Jamais dans la config commune :
# sur une machine AMD ou Intel, forcer le pilote NVIDIA casserait l'affichage.
#
# Exemple de /etc/palingoneos-local/machine.nix pour un PC fixe avec une GTX 1070 :
#   {
#     palingoneos.nvidia.enable = true;
#     palingoneos.nvidia.legacy = true;
#   }
#
# Les cartes AMD (Radeon) et Intel n'ont besoin de RIEN : Mesa (libre) est déjà inclus.
{ config, lib, pkgs, ... }:

let
  cfg = config.palingoneos.nvidia;
in
{
  options.palingoneos.nvidia = {
    enable = lib.mkEnableOption "le pilote propriétaire NVIDIA sur cette machine";

    legacy = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        true pour les cartes GTX 9xx et GTX 10xx (2014-2017, ex. GTX 1070) :
        elles utilisent la branche 580 du pilote, la dernière qui les prend en charge
        (suivie jusqu'en août 2028), avec le module noyau fermé.
        false pour les RTX (20xx et plus) et GTX 16xx : pilote actuel, module « open ».
      '';
    };

    # Portables avec DEUX puces graphiques (la puce intégrée Intel/AMD + la NVIDIA).
    # Mode « offload » : l'écran tourne sur la puce intégrée (économe en batterie),
    # la NVIDIA ne travaille que pour ce qu'on lance dessus :
    #   - clic droit sur une application dans COSMIC → « carte graphique dédiée » ;
    #   - ou, dans Steam : Propriétés du jeu → Options de lancement : nvidia-offload %command%
    prime = {
      enable = lib.mkEnableOption "le mode portable à deux puces graphiques (PRIME offload)";

      nvidiaBusId = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "PCI:1@0:0:0";
        description = "Adresse de la puce NVIDIA (donnée par lspci, convertie en décimal).";
      };
      intelBusId = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "PCI:0@0:2:0";
        description = "Adresse de la puce intégrée Intel (laisser vide si elle est AMD).";
      };
      amdgpuBusId = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "PCI:5@0:0:0";
        description = "Adresse de la puce intégrée AMD (laisser vide si elle est Intel).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Charge le pilote NVIDIA (pour COSMIC/Wayland comme pour les vieux programmes X11).
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      # Branche du pilote : 580 pour les anciennes cartes, la plus récente stable sinon.
      branch = if cfg.legacy then "legacy_580" else "stable";
      # Module noyau « open » : seulement pour les RTX / GTX 16xx et plus récentes.
      open = !cfg.legacy;
      # Obligatoire pour COSMIC (Wayland).
      modesetting.enable = true;
      # Sauvegarde la mémoire de la carte en veille : évite l'écran corrompu au réveil.
      powerManagement.enable = true;
      # Le panneau de réglages NVIDIA.
      nvidiaSettings = true;

      prime = lib.mkIf cfg.prime.enable {
        offload.enable = true;
        # Ajoute la commande « nvidia-offload » (pour les options de lancement Steam).
        offload.enableOffloadCmd = true;
        inherit (cfg.prime) nvidiaBusId intelBusId amdgpuBusId;
      };
    };
  };
}
