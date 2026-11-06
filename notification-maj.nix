# PalinGoneOS — prévenir quand une mise à jour est disponible.
#
# Toutes les heures, une petite vérification compare la version installée à la
# dernière version publiée sur GitHub (comme le Centre de maintenance, sans aucun
# droit administrateur). S'il y a du nouveau, une notification COSMIC s'affiche :
#   « Mise à jour disponible — PalinGoneOS X.Y.Z est prête. »
# Un clic sur la notification (ou sur son bouton « Mettre à jour ») ouvre le
# Centre de maintenance. Rien ne s'installe jamais tout seul.
#
# Pour ne pas déranger : une version déjà annoncée n'est rappelée qu'une fois par jour,
# et rien ne s'affiche si le Centre de maintenance est déjà ouvert.
#
# Pour tester (affiche la notification même si tout est à jour) :
#   palingoneos-verif-maj --test
{ config, pkgs, inputs, ... }:

let
  updater = inputs.palingoneos-updater.packages.${pkgs.stdenv.hostPlatform.system}.palin-gone-os-updater;

  verification = pkgs.writeShellApplication {
    name = "palingoneos-verif-maj";
    runtimeInputs = [
      pkgs.git
      pkgs.libnotify # notify-send : la notification
      pkgs.coreutils
      pkgs.gnused
      pkgs.procps # pgrep : le Centre est-il déjà ouvert ?
      config.systemd.package # systemd-run : ouvrir le Centre
    ];
    text = ''
      TEST=0
      if [ "''${1:-}" = "--test" ]; then TEST=1; fi

      actuelle="$(cat /etc/palingoneos/version 2>/dev/null || true)"
      [ -n "$actuelle" ] || exit 0

      # Dernière version publiée : même commande que le Centre de maintenance.
      # Sans Internet, on s'arrête en silence (on réessaiera dans une heure).
      if ! publiees="$(GIT_TERMINAL_PROMPT=0 git \
        -c safe.directory=/etc/nixos \
        -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=15 \
        -C /etc/nixos ls-remote --tags --refs origin 'v*' 2>/dev/null)"; then
        exit 0
      fi
      derniere="$(printf '%s\n' "$publiees" |
        sed -nE 's|.*refs/tags/v([0-9]+\.[0-9]+\.[0-9]+)$|\1|p' | sort -V | tail -n 1)"

      if [ "$TEST" = 0 ]; then
        # Rien de nouveau ?
        if [ -z "$derniere" ] || [ "$derniere" = "$actuelle" ] ||
          [ "$(printf '%s\n%s\n' "$actuelle" "$derniere" | sort -V | tail -n 1)" != "$derniere" ]; then
          exit 0
        fi
        # Le Centre de maintenance est déjà ouvert : il affiche déjà la nouvelle version.
        if pgrep -u "$(id -u)" -f 'bin/palin-gone-os-updater( |$)' >/dev/null; then exit 0; fi
        # Déjà annoncée il y a moins de 24 heures : on ne dérange pas.
        memoire="''${XDG_STATE_HOME:-$HOME/.local/state}/palingoneos/notification-maj"
        maintenant="$(date +%s)"
        if read -r version_annoncee date_annonce 2>/dev/null <"$memoire" &&
          [ "$version_annoncee" = "$derniere" ] &&
          [ $((maintenant - date_annonce)) -lt 86400 ]; then
          exit 0
        fi
        mkdir -p "$(dirname "$memoire")"
        echo "$derniere $maintenant" >"$memoire"
      fi

      # La notification. « default » = clic sur la notification elle-même.
      # notify-send attend la réponse (au plus 50 minutes, avant la vérification suivante).
      choix="$(timeout 50m notify-send \
        --app-name="PalinGoneOS" \
        --wait \
        --icon="${updater}/share/icons/hicolor/512x512/apps/palin-gone-os-updater.png" \
        --action=default="Ouvrir le Centre de maintenance" \
        --action=ouvrir="Mettre à jour" \
        "Mise à jour disponible" \
        "PalinGoneOS ''${derniere:-} est prête. Cliquez ici pour l'installer." || true)"

      if [ "$choix" = default ] || [ "$choix" = ouvrir ]; then
        # systemd-run : le Centre vit dans sa propre unité, indépendante de cette vérification.
        systemd-run --user --collect --quiet -- "${updater}/bin/palin-gone-os-updater"
      fi
    '';
  };
in
{
  environment.systemPackages = [ verification ];

  systemd.user.services.palingoneos-verif-maj = {
    description = "PalinGoneOS — recherche d'une mise à jour";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${verification}/bin/palingoneos-verif-maj";
    };
  };

  # Le Centre de maintenance s'ouvre déjà à chaque connexion : la première
  # vérification a donc lieu une heure après, puis toutes les heures.
  systemd.user.timers.palingoneos-verif-maj = {
    description = "PalinGoneOS — recherche d'une mise à jour toutes les heures";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    timerConfig = {
      OnActiveSec = "1h";
      OnUnitActiveSec = "1h";
      RandomizedDelaySec = "5min"; # les machines de la famille n'interrogent pas GitHub à la même seconde
    };
  };
}
