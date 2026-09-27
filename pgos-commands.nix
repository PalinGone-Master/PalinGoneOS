# PalinGoneOS — commandes pratiques préfixées "pgos-", disponibles dans le
# shell de tous les comptes, avec pages de manuel (man) en français.
{ config, lib, pkgs, ... }:

let
  # Utilise le même binaire nixos-rebuild que celui choisi par le système,
  # plutôt qu'un paquet nixpkgs générique.
  nixosRebuild = config.system.build.nixos-rebuild;

  pgosRebuild = pkgs.writeShellApplication {
    name = "pgos-rebuild";
    text = ''
      if [ "''${1:-}" = "-h" ] || [ "''${1:-}" = "--help" ]; then
        echo "Usage : pgos-rebuild"
        echo "Construit PalinGoneOS en local, sans rien activer. Voir : man pgos-rebuild"
        exit 0
      fi
      echo "==> Construction de test de PalinGoneOS (RIEN n'est activé sur cette machine)…"
      sudo ${nixosRebuild}/bin/nixos-rebuild build --flake /etc/nixos#palingoneos
      echo "==> OK : la configuration compile correctement."
    '';
  };

  pgosSwitch = pkgs.writeShellApplication {
    name = "pgos-switch";
    text = ''
      if [ "''${1:-}" = "-h" ] || [ "''${1:-}" = "--help" ]; then
        echo "Usage : pgos-switch"
        echo "Construit ET active PalinGoneOS immédiatement sur cette machine. Voir : man pgos-switch"
        exit 0
      fi
      echo "==> Construction ET activation immédiate de PalinGoneOS sur cette machine…"
      sudo ${nixosRebuild}/bin/nixos-rebuild switch --flake /etc/nixos#palingoneos
    '';
  };

  pgosVersion = pkgs.writeShellApplication {
    name = "pgos-version";
    text = ''
      if [ "''${1:-}" = "-h" ] || [ "''${1:-}" = "--help" ]; then
        echo "Usage : pgos-version"
        echo "Affiche la version de PalinGoneOS installée sur cette machine. Voir : man pgos-version"
        exit 0
      fi
      if [ -f /etc/palingoneos/version ]; then
        cat /etc/palingoneos/version
      else
        echo "Version inconnue (fichier /etc/palingoneos/version introuvable)."
      fi
    '';
  };

  # Pages de manuel en français (format troff/man classique).
  # Installées directement dans share/man/man1 (pas de sous-dossier de
  # langue) pour qu'elles s'affichent quel que soit le réglage de locale
  # de l'utilisateur qui tape "man pgos-rebuild".
  pgosManPages = pkgs.runCommand "pgos-man-pages" { } ''
    mkdir -p $out/share/man/man1

    cat > $out/share/man/man1/pgos-rebuild.1 << 'EOF'
.TH PGOS-REBUILD 1 "2026" "PalinGoneOS" "Commandes PalinGoneOS"
.SH NOM
pgos-rebuild \- teste la construction de PalinGoneOS sans rien activer
.SH SYNOPSIS
.B pgos-rebuild
.SH DESCRIPTION
Construit la configuration NixOS de PalinGoneOS à partir du dépôt local
(/etc/nixos), pour vérifier qu'elle compile correctement.
.PP
Rien n'est activé sur la machine : c'est une vérification sans risque,
à faire avant toute publication d'une nouvelle version.
.PP
Demande le mot de passe administrateur (sudo).
.SH VOIR AUSSI
.BR pgos-switch (1),
.BR pgos-version (1)
EOF

    cat > $out/share/man/man1/pgos-switch.1 << 'EOF'
.TH PGOS-SWITCH 1 "2026" "PalinGoneOS" "Commandes PalinGoneOS"
.SH NOM
pgos-switch \- construit et active PalinGoneOS immédiatement sur cette machine
.SH SYNOPSIS
.B pgos-switch
.SH DESCRIPTION
Construit la configuration NixOS de PalinGoneOS à partir du dépôt local
(/etc/nixos) et l'active tout de suite sur cette machine.
.PP
Contrairement au Centre de mise à jour, cette commande n'installe pas une
version publiée sur GitHub : elle applique l'état actuel du dépôt local,
tel quel. À réserver à un usage de test/développement.
.PP
Demande le mot de passe administrateur (sudo).
.SH VOIR AUSSI
.BR pgos-rebuild (1),
.BR pgos-version (1)
EOF

    cat > $out/share/man/man1/pgos-version.1 << 'EOF'
.TH PGOS-VERSION 1 "2026" "PalinGoneOS" "Commandes PalinGoneOS"
.SH NOM
pgos-version \- affiche la version de PalinGoneOS installée
.SH SYNOPSIS
.B pgos-version
.SH DESCRIPTION
Affiche le numéro de version de PalinGoneOS actuellement installé sur
cette machine, lu depuis /etc/palingoneos/version.
.SH VOIR AUSSI
.BR pgos-rebuild (1),
.BR pgos-switch (1)
EOF
  '';
in
{
  environment.systemPackages = [
    pgosRebuild
    pgosSwitch
    pgosVersion
    pgosManPages
  ];
}
