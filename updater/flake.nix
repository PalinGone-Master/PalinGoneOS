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
          src = ./.;
          dontUnpack = true;

          nativeBuildInputs = [ pkgs.autoPatchelfHook pkgs.makeWrapper ];
          buildInputs = [
            pkgs.libxkbcommon
            pkgs.wayland
            pkgs.libglvnd
            pkgs.stdenv.cc.cc.lib
            pkgs.xorg.libX11
            pkgs.xorg.libXcursor
            pkgs.xorg.libXrandr
            pkgs.xorg.libXi
          ];

          installPhase = ''
            mkdir -p $out/bin $out/share/applications
            cp $src/bin/palin-gone-os-updater $out/bin/palin-gone-os-updater
            chmod +x $out/bin/palin-gone-os-updater

            if [ -d "$src/share/applications" ]; then
              cp -r $src/share/applications/* $out/share/applications/
            fi

            wrapProgram $out/bin/palin-gone-os-updater \
              --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath [
                pkgs.wayland
                pkgs.libxkbcommon
                pkgs.libglvnd
                pkgs.stdenv.cc.cc.lib
                pkgs.xorg.libX11
                pkgs.xorg.libXcursor
                pkgs.xorg.libXrandr
                pkgs.xorg.libXi
              ]}"
          '';
        };

        defaultPackage = self.packages.${system}.palin-gone-os-updater;
      }
    );
}
