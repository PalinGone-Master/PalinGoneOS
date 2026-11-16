# PalinGoneOS — comptes en ligne (Google Drive, OneDrive...) ouverts comme des dossiers.
#
# On ajoute ses comptes avec l'application « Rclone UI » (ou rclone config), en leur
# donnant le nom qu'on veut. Chaque compte apparaît ensuite tout seul dans
#   ~/Cloud/<nom du compte>
# à chaque connexion, et un compte ajouté en cours de session apparaît en moins de
# 2 minutes. Ce que l'on met dans ces dossiers part sur le cloud.
#
# Ne ralentit ni le démarrage ni la connexion : tout se passe en arrière-plan, dans la
# session (pas au démarrage de l'ordinateur). Sans Internet, chaque compte réessaie
# tout seul toutes les 30 secondes. À la déconnexion, tout se ferme proprement.
#
# Commandes utiles :
#   systemctl --user list-units 'palingoneos-cloud@*'     comptes ouverts
#   journalctl --user -u 'palingoneos-cloud@*' -n 30      messages
{ config, pkgs, ... }:

let
  # Ouvre UN compte (son nom en argument) dans ~/Cloud/<nom>.
  ouvrirCompte = pkgs.writeShellApplication {
    name = "palingoneos-cloud-compte";
    runtimeInputs = [ pkgs.rclone pkgs.util-linux pkgs.gnugrep pkgs.coreutils ];
    text = ''
      NOM="$1"
      DOSSIER="$HOME/Cloud/$NOM"

      # Compte supprimé entre-temps : rien à faire.
      if ! rclone listremotes 2>/dev/null | grep -qxF "$NOM:"; then
        echo "Le compte « $NOM » n'existe plus dans rclone."
        exit 0
      fi

      mkdir -p "$DOSSIER"
      if mountpoint -q "$DOSSIER"; then
        echo "« $NOM » est déjà ouvert."
        exit 0
      fi
      # Des fichiers ont été mis dans ce dossier pendant qu'il était fermé : ils sont
      # restés sur l'ordinateur et empêchent l'ouverture. On ne les touche pas.
      if [ -n "$(ls -A "$DOSSIER")" ]; then
        echo "Le dossier $DOSSIER contient des fichiers restés sur l'ordinateur :" >&2
        echo "déplacez-les ailleurs ; « $NOM » s'ouvrira tout seul ensuite." >&2
        exit 0
      fi

      # fusermount3 : nécessaire pour ouvrir un dossier sans être administrateur.
      export PATH="/run/wrappers/bin:$PATH"
      exec rclone mount "$NOM:" "$DOSSIER" --vfs-cache-mode writes --volname "$NOM"
    '';
  };

  # Passe en revue les comptes de rclone et ouvre ceux qui ne le sont pas encore.
  ouvrirTout = pkgs.writeShellApplication {
    name = "palingoneos-cloud";
    runtimeInputs = [ pkgs.rclone pkgs.coreutils config.systemd.package ];
    text = ''
      rclone listremotes 2>/dev/null | while IFS= read -r compte; do
        nom="''${compte%:}"
        [ -n "$nom" ] || continue
        systemctl --user start --no-block "palingoneos-cloud@$(systemd-escape "$nom").service"
      done
    '';
  };
in
{
  environment.systemPackages = [ ouvrirTout ];

  # Un service par compte : palingoneos-cloud@<nom>.service
  systemd.user.services."palingoneos-cloud@" = {
    description = "PalinGoneOS — compte en ligne « %I » dans ~/Cloud";
    partOf = [ "graphical-session.target" ];
    # Réessaie sans fin (toutes les 30 s) tant qu'Internet n'est pas là.
    startLimitIntervalSec = 0;
    serviceConfig = {
      Type = "simple";
      ExecStart = ''${ouvrirCompte}/bin/palingoneos-cloud-compte "%I"'';
      Restart = "on-failure";
      RestartSec = "30s";
    };
  };

  # La revue des comptes : 20 s après la connexion, puis toutes les 2 minutes
  # (lire la liste des comptes est instantané et ne passe pas par Internet).
  systemd.user.services.palingoneos-cloud = {
    description = "PalinGoneOS — ouvrir les comptes en ligne dans ~/Cloud";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${ouvrirTout}/bin/palingoneos-cloud";
    };
  };
  systemd.user.timers.palingoneos-cloud = {
    description = "PalinGoneOS — ouvrir les comptes en ligne dans ~/Cloud";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    timerConfig = {
      OnActiveSec = "20s";
      OnUnitActiveSec = "2min";
    };
  };
}
