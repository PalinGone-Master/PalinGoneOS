# PalinGoneOS — machine virtuelle Windows pour les logiciels sans équivalent Linux
# (ex. mise à jour des cartes GPS Peugeot, diagnostic occasionnel).
#
# Utilisation : virt-manager (dans le menu). Pour brancher une clé USB ou la sonde
# de diagnostic dans la VM une fois Windows démarré : menu de la fenêtre de la VM
# → Virtual Machine → Redirect USB device. Aucune manipulation Nix nécessaire,
# et aucun mot de passe à chaque branchement (géré par la règle polkit du module).
{ pkgs, ... }:

{
  virtualisation.libvirtd = {
    enable = true;
    # UEFI (OVMF) : fourni par défaut avec QEMU dans cette version de nixpkgs.
    # TPM virtuel, requis pour installer Windows 11 :
    qemu.swtpm.enable = true;
  };

  # Interface graphique pour créer/gérer les VM.
  programs.virt-manager.enable = true;

  # Presse-papiers et redimensionnement d'écran partagés avec la VM (confort, facultatif).
  services.spice-vdagentd.enable = true;

  # Accès à virt-manager sans mot de passe à chaque fois (la règle polkit du module
  # libvirtd n'autorise que les membres de ce groupe).
  users.users.palingone.extraGroups = [ "libvirtd" ];
}
