# PalinGoneOS — bureau à distance.
#
# Remmina : SE CONNECTER à un autre ordinateur (RDP/Windows, VNC, SSH, SPICE…).
#           Client seulement : aucun port n'est ouvert sur cette machine.
# RustDesk : assistance à distance (aider un proche, ou être aidé).
#           Aucun port entrant à ouvrir : la connexion passe par les serveurs de RustDesk.
#           Le service permanent (accès sans confirmation) n'est volontairement PAS activé :
#           la personne aidée ouvre RustDesk, communique son identifiant, et valide la connexion.
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    remmina
    rustdesk-flutter
  ];
}
