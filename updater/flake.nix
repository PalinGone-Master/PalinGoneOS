{
  description = "PalinGoneOS Welcome & Updater (Rust/Iced Application)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages.palin-gone-os-updater = pkgs.rustPlatform.buildRustPackage {
          pname = "palin-gone-os-updater";
          version = "1.2.0";
          src = ./.;

          cargoLock = {
            lockFile = ./Cargo.lock;
          };

          nativeBuildInputs = [ pkgs.pkg-config pkgs.makeWrapper ];
          buildInputs = [
            pkgs.libxkbcommon
            pkgs.wayland
            pkgs.libglvnd
            pkgs.libGL
            pkgs.mesa
            pkgs.stdenv.cc.cc.lib
            pkgs.libx11
            pkgs.libxcursor
            pkgs.libxi
            pkgs.libxrandr
            pkgs.vulkan-loader
          ];

          postInstall = ''
            mkdir -p $out/share/applications $out/etc/xdg/autostart
            if [ -d "share/applications" ]; then
              cp -r share/applications/* $out/share/applications/
              cp -r share/applications/* $out/etc/xdg/autostart/
            fi

            # Icône PalinGoneOS (losange + P), à la place de l'icône générique système.
            install -Dm644 ${./branding/icon-512.png} \
              $out/share/icons/hicolor/512x512/apps/palin-gone-os-updater.png
            for f in $out/share/applications/*.desktop $out/etc/xdg/autostart/*.desktop; do
              sed -i "s|^Icon=.*|Icon=$out/share/icons/hicolor/512x512/apps/palin-gone-os-updater.png|" "$f"
            done

wrapProgram $out/bin/palin-gone-os-updater \
  --prefix PATH : "${pkgs.lib.makeBinPath [ pkgs.git pkgs.nixos-rebuild ]}" \
  --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath [
    pkgs.wayland
    pkgs.libxkbcommon
    pkgs.libglvnd
    pkgs.libGL
    pkgs.mesa
    pkgs.vulkan-loader
    pkgs.stdenv.cc.cc.lib
    pkgs.libx11
    pkgs.libxcursor
    pkgs.libxi
    pkgs.libxrandr
  ]}:/run/opengl-driver/lib"
          '';
        };

        defaultPackage = self.packages.${system}.palin-gone-os-updater;
      }
    );
}
