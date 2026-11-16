# PalinGoneOS — accès SSH, uniquement depuis le réseau local, uniquement par clé.
#
# - Connexion par CLÉ seulement : aucun mot de passe n'est accepté, impossible à deviner.
# - Seul le compte principal peut se connecter, jamais root (sudo redemande le mot de passe).
# - Le port 22 n'est ouvert qu'aux adresses du réseau local (box, Wi-Fi de la maison) :
#   depuis Internet, il reste fermé.
# - Les clés autorisées sont les fichiers .pub du dossier ssh/cles/ (clés PUBLIQUES,
#   sans danger dans un dépôt public).
#
# Pour se connecter depuis un autre ordinateur de la maison :
#   ssh <identifiant>@<nom-de-la-machine>.local      (ex. ssh dylan@pc-dylan.local)
{ config, lib, ... }:

let
  utilisateur = config.palingoneos.utilisateur.identifiant;
  dossierCles = ./ssh/cles;
  cles = map (nom: dossierCles + "/${nom}")
    (builtins.filter (nom: lib.hasSuffix ".pub" nom) (builtins.attrNames (builtins.readDir dossierCles)));
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

  users.users.${utilisateur}.openssh.authorizedKeys.keyFiles = cles;

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
