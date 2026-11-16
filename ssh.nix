# PalinGoneOS — accès SSH, uniquement depuis le réseau local, uniquement par clé.
#
# - Connexion par CLÉ seulement : aucun mot de passe n'est accepté, impossible à deviner.
# - Seul le compte principal peut se connecter, jamais root (sudo redemande le mot de passe).
# - Le port 22 n'est ouvert qu'aux adresses du réseau local (box, Wi-Fi de la maison) :
#   depuis Internet, il reste fermé.
# - Deux sortes de clés autorisées :
#     * celles de l'administrateur : fichiers .pub du dossier ssh/cles/ du dépôt
#       (clés PUBLIQUES, sans danger dans un dépôt public), valables sur TOUTES les machines ;
#     * celles que chaque utilisateur choisit pour SON ordinateur, avec la commande
#       pgos-ssh (rangées dans ~/.ssh/authorized_keys, propres à cette machine).
#   Exemple : quelqu'un qui a deux ordinateurs autorise l'un à se connecter à l'autre
#   avec « pgos-ssh ma-cle » sur le premier et « pgos-ssh autoriser ... » sur le second.
#
# Pour se connecter depuis un autre ordinateur de la maison :
#   ssh <identifiant>@<nom-de-la-machine>.local      (ex. ssh dylan@pc-dylan.local)
{ config, lib, pkgs, ... }:

let
  utilisateur = config.palingoneos.utilisateur.identifiant;
  dossierCles = ./ssh/cles;
  cles = map (nom: dossierCles + "/${nom}")
    (builtins.filter (nom: lib.hasSuffix ".pub" nom) (builtins.attrNames (builtins.readDir dossierCles)));

  # pgos-ssh : gérer simplement, sans connaître SSH, qui peut se connecter à CET ordinateur.
  pgosSsh = pkgs.writeShellApplication {
    name = "pgos-ssh";
    runtimeInputs = [ pkgs.openssh pkgs.coreutils pkgs.gnugrep pkgs.gnused pkgs.gawk ];
    text = builtins.readFile ./ssh/pgos-ssh.sh;
  };

  pgosSshMan = pkgs.runCommand "pgos-ssh-man" { } ''
    install -Dm644 ${./ssh/pgos-ssh.1} $out/share/man/man1/pgos-ssh.1
  '';
in
{
  services.openssh = {
    enable = true;
    # Pas d'ouverture automatique du pare-feu : elle est faite ci-dessous, réseau local seulement.
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ utilisateur ];
    };
  };

  # Clés de l'administrateur (dépôt). Les clés choisies par l'utilisateur
  # (~/.ssh/authorized_keys, via pgos-ssh) sont lues en plus, par défaut.
  users.users.${utilisateur}.openssh.authorizedKeys.keyFiles = cles;

  environment.systemPackages = [ pgosSsh pgosSshMan ];

  # Port 22 ouvert uniquement aux adresses privées (réseau local) :
  # IPv4 10.x, 172.16-31.x, 192.168.x ; IPv6 locales (fe80::, fd00::).
  networking.firewall.extraInputRules = ''
    ip saddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 } tcp dport 22 accept comment "SSH reseau local"
    ip6 saddr { fe80::/10, fd00::/8 } tcp dport 22 accept comment "SSH reseau local"
  '';

  # Chaque machine annonce son nom sur le réseau local (pc-dylan.local...) :
  # on peut s'y connecter par son nom, sans chercher son adresse.
  services.avahi.publish = {
    enable = true;
    addresses = true;
  };
}
