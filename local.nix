# PalinGoneOS — réglages propres à CETTE machine (facultatifs).
#
# Si le fichier /etc/palingoneos-local/machine.nix existe, il est chargé.
# Il est HORS du dépôt : les mises à jour n'y touchent jamais.
# Sur une machine qui n'en a pas besoin (la plupart), il n'existe simplement pas.
#
# Exemple d'usage : allumer le pilote NVIDIA sur une machine qui a une carte NVIDIA
# (voir nvidia.nix).
{ lib, ... }:

{
  imports = lib.optional
    (builtins.pathExists /etc/palingoneos-local/machine.nix)
    /etc/palingoneos-local/machine.nix;
}
