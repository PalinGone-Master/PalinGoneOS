{
  description = "PalinGoneOS Updater (Prebuilt, Patched & Wrapped)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages.palin-gone-os-updater = pkgs.stdenv.mkDerivation {
          pname = "palin-gone-os-updater";
          version = "1.1.0";
          src = ./bin/palin-gone-os-updater;
          dontUnpack = true;

          nativeBuildInputs = [ pkgs.autoPatchelfHook pkgs.makeWrapper ];
          buildInputs = [
            pkgs.libxkbcommon
            pkgs.wayland
            pkgs.libglvnd
            pkgs.stdenv.cc.cc.lib
          ];

          installPhase = ''
            mkdir -p $out/bin
            cp $src $out/bin/palin-gone-os-updater
            chmod +x $out/bin/palin-gone-os-updater

            wrapProgram $out/bin/palin-gone-os-updater \
              --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath [
                pkgs.wayland
                pkgs.libxkbcommon
                pkgs.libglvnd
                pkgs.stdenv.cc.cc.lib
              ]}"
          '';
        };

        defaultPackage = self.packages.${system}.palin-gone-os-updater;
      }
    );
}
