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
          version = "1.1.0";
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

            wrapProgram $out/bin/palin-gone-os-updater \
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
