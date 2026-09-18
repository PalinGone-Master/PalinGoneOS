{
 # Systeme PalinGoneOS
 description = "PalinGoneOS";

 # Source du Systeme 
 inputs = {

 # Passage à unstable pour les derniers logiciel
   nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";


 # Gestion de flatpak
   nix-flatpak.url = "github:gmodena/nix-flatpak";



 # L'updater de PalinGoneOS
  palingoneos-updater.url = "github:PalinGone-Master/palingoneos-updater/v1.0";
  };


 # Production du flake
 outputs = { self, nixpkgs, nix-flatpak, ... }: {

    # Configuration Machine
    nixosConfigurations.palingoneos = nixpkgs.lib.nixosSystem {

      # Architecture en x86_64 (PAS DE SUPPORT ARM)
      system = "x86_64-linux";
     
      # Configuration Principale
      modules = [
	./configuration.nix
      # Configuration du module Flatpak
      nix-flatpak.nixosModules.nix-flatpak

      {
        system.configurationRevision = self.rev or self.dirtyRev;
      }
      ];
    };
  };
}
