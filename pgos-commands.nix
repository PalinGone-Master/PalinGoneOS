# PalinGoneOS — commandes pratiques préfixées "pgos-", disponibles dans le
# shell de tous les comptes (aucune n'est activée sans confirmation explicite
# de l'utilisateur ; "switch" demande le mot de passe sudo comme d'habitude).
{ config, lib, pkgs, ... }:

let
  # Utilise le même binaire nixos-rebuild que celui choisi par le système,
  # plutôt qu'un paquet nixpkgs générique.
  nixosRebuild = config.system.build.nixos-rebuild;

  pgosRebuild = pkgs.writeShellApplication {
    name = "pgos-rebuild";
    text = ''
      echo "==> Construction de test de PalinGoneOS (RIEN n'est activé sur cette machine)…"
      sudo ${nixosRebuild}/bin/nixos-rebuild build --flake /etc/nixos#palingoneos
      echo "==> OK : la configuration compile correctement."
    '';
  };

  pgosSwitch = pkgs.writeShellApplication {
    name = "pgos-switch";
    text = ''
      echo "==> Construction ET activation immédiate de PalinGoneOS sur cette machine…"
      sudo ${nixosRebuild}/bin/nixos-rebuild switch --flake /etc/nixos#palingoneos
    '';
  };

  pgosVersion = pkgs.writeShellApplication {
    name = "pgos-version";
    text = ''
      if [ -f /etc/palingoneos/version ]; then
        cat /etc/palingoneos/version
      else
        echo "Version inconnue (fichier /etc/palingoneos/version introuvable)."
      fi
    '';
  };
in
{
  environment.systemPackages = [
    pgosRebuild
    pgosSwitch
    pgosVersion
  ];
}
