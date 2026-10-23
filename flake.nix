{
  # Systeme PalinGoneOS
  description = "PalinGoneOS";

  inputs = {
    # Passage à unstable pour les derniers logiciels
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Gestion de flatpak
    nix-flatpak.url = "github:gmodena/nix-flatpak";

    # L'updater de PalinGoneOS (Chemin relatif local au dépôt /etc/nixos)
    palingoneos-updater.url = "path:./updater";
    # Même version de nixpkgs partout (évite un second téléchargement et des écarts de compilateur)
    palingoneos-updater.inputs.nixpkgs.follows = "nixpkgs";
  };

  # Production du flake
  outputs = inputs@{ self, nixpkgs, nix-flatpak, ... }: {

    # Configuration Machine
    nixosConfigurations.palingoneos = nixpkgs.lib.nixosSystem {

      # Architecture en x86_64 (PAS DE SUPPORT ARM)
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };

      # Configuration Principale
      modules = [
        ./configuration.nix
        # Configuration du module Flatpak
        nix-flatpak.nixosModules.nix-flatpak

        {
          system.configurationRevision = self.rev or self.dirtyRev or "unknown";
        }
      ];
    };

    # Clé USB d'installation de PalinGoneOS (voir installer/iso.nix).
    # Construire avec : nix build .#iso   →   result/iso/PalinGoneOS-installateur.iso
    nixosConfigurations.installer = nixpkgs.lib.nixosSystem {
      modules = [ ./installer/iso.nix ];
    };
    packages.x86_64-linux.iso = self.nixosConfigurations.installer.config.system.build.isoImage;
  };
}
