# PalinGoneOS — ordonnanceur sched_ext (le système reste réactif même quand il est très chargé).
#
# Depuis novembre 2026, NixOS a remplacé « services.scx » par « services.scx-loader » :
# l'ancien réglage faisait échouer la construction (et donc la mise à jour automatique).
{ config, lib, pkgs, ... }:

{
  services.scx-loader = {
    enable = true;
    # Ordonnanceur lancé au démarrage (scx_bpfland = alternative plus généraliste).
    config.default_sched = "scx_lavd";
  };
}
