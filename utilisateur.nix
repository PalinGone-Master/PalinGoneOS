# PalinGoneOS — le compte principal de la machine.
#
# Chaque machine choisit, dans /etc/palingoneos-local/machine.nix (l'installateur les y écrit) :
#   palingoneos.utilisateur.identifiant = "dylan";   # nom technique : terminal, dossier /home/dylan
#   palingoneos.utilisateur.nom = "Dylan";           # nom affiché sur l'écran de connexion
# Sans réglage (machines installées avant la v0.31.27), c'est « palingone » / « PalinGone ».
#
# Les autres modules (jeux, VM Windows…) utilisent config.palingoneos.utilisateur.identifiant
# au lieu d'écrire « palingone » en dur.
{ config, lib, ... }:

let
  cfg = config.palingoneos.utilisateur;
in
{
  options.palingoneos.utilisateur = {
    identifiant = lib.mkOption {
      type = lib.types.strMatching "[a-z][a-z0-9_-]{0,30}";
      default = "palingone";
      example = "dylan";
      description = "Identifiant du compte principal : minuscules, sans accent ni espace.";
    };
    nom = lib.mkOption {
      type = lib.types.str;
      default = "PalinGone";
      example = "Dylan";
      description = "Nom affiché sur l'écran de connexion.";
    };
  };

  config = {
    # Aucun mot de passe dans ce fichier : le dépôt est PUBLIC.
    # Le mot de passe se change avec la commande `passwd`.
    users.users.${cfg.identifiant} = {
      isNormalUser = true;
      # mkDefault : les machine.nix créés avant la v0.31.27 écrivent directement
      # « users.users.palingone.description = ... », qui doit garder la priorité.
      description = lib.mkDefault cfg.nom;
      extraGroups = [ "wheel" "networkmanager" ];
    };
  };
}
