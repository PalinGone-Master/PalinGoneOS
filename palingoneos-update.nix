# PalinGoneOS — service de mise à jour du système.
#
# À importer dans configuration.nix :  imports = [ ./hardware-configuration.nix ./palingoneos-update.nix ];
# et à SUPPRIMER de configuration.nix :
#   - la règle sudo NOPASSWD sur nixos-rebuild
#   - le script « palingoneos-update-helper »
#
# Principe : l'interface (utilisateur normal) démarre `palingoneos-update@X.Y.Z.service`.
# Polkit n'autorise que ça, uniquement pour ce nom d'unité, uniquement pour le groupe wheel,
# uniquement depuis une session locale active. Le flake (/etc/nixos#palingoneos) est fixé
# ici : l'utilisateur ne peut plus faire exécuter un flake arbitraire en root.
{ config, lib, pkgs, ... }:

let
  updateScript = pkgs.writeShellApplication {
    name = "palingoneos-update-run";
    runtimeInputs = [ pkgs.git pkgs.util-linux pkgs.coreutils config.nix.package ];
    text = ''
      VERSION="''${1:-}"

      # Seul un numéro X.Y.Z strict est accepté (pas de chemin, pas d'option git).
      if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Version invalide : « $VERSION »" >&2
        exit 2
      fi

      # Une seule mise à jour à la fois.
      exec 9>/run/palingoneos-update.lock
      if ! flock -n 9; then
        echo "Une mise à jour est déjà en cours." >&2
        exit 3
      fi

      cd /etc/nixos
      PREV="$(git rev-parse HEAD)"

      echo "==> Téléchargement de la version $VERSION"
      git fetch --tags --force origin

      # Optionnel mais recommandé une fois tes tags signés (git tag -s) :
      # git verify-tag "v$VERSION"

      git checkout --force "v$VERSION"

      echo "==> Construction et activation du système (patience…)"
      if ! /run/current-system/sw/bin/nixos-rebuild switch --flake /etc/nixos#palingoneos; then
        echo "==> ÉCHEC : retour à la version précédente" >&2
        git checkout --force "$PREV"
        exit 1
      fi

      echo "==> Mise à jour terminée"
    '';
  };
in
{
  systemd.services."palingoneos-update@" = {
    description = "PalinGoneOS — mise à jour vers la version %i";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${updateScript}/bin/palingoneos-update-run %i";
      Environment = "HOME=/root";
    };
    # Sans ces deux lignes, `nixos-rebuild switch` peut redémarrer ce service pendant qu'il tourne.
    restartIfChanged = false;
    stopIfChanged = false;
  };

  security.polkit.enable = true;
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("verb") == "start" &&
          /^palingoneos-update@[0-9]+\.[0-9]+\.[0-9]+\.service$/.test(action.lookup("unit")) &&
          subject.local && subject.active &&
          subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';
}
