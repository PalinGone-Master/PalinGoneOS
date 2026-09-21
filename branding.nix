# PalinGoneOS — identité visuelle : nom, version, fond d'écran, écran de démarrage, fastfetch.
{ config, lib, pkgs, ... }:

let
  version = config.palingoneos.version;

  # Fond d'écran PalinGoneOS installé comme valeur PAR DÉFAUT de COSMIC, pour TOUS les
  # utilisateurs (présents et futurs). COSMIC lit d'abord la config de l'utilisateur
  # (~/.config/cosmic/...), puis, à défaut, ce dossier « share/cosmic » du système.
  brandingPackage = pkgs.runCommand "palingoneos-branding" { } ''
    install -Dm644 ${./branding/wallpaper.png} $out/share/backgrounds/palingoneos/wallpaper.png

    dir=$out/share/cosmic/com.system76.CosmicBackground/v1
    mkdir -p "$dir"
    cat > "$dir/all" <<EOF
    (
        output: "all",
        source: Path("$out/share/backgrounds/palingoneos/wallpaper.png"),
        filter_by_theme: true,
        rotation_frequency: 300,
        filter_method: Lanczos,
        scaling_mode: Zoom,
        sampling_method: Alphanumeric,
    )
    EOF
    echo true > "$dir/same-on-all"
  '';
in
{
  options.palingoneos.version = lib.mkOption {
    type = lib.types.str;
    example = "0.31.4";
    description = "Version de PalinGoneOS (X.Y.Z). Doit correspondre au tag Git publié (vX.Y.Z).";
  };

  config = {
    #==========================================
    # Identité de la distribution
    #==========================================
    system.nixos.distroName = "PalinGoneOS";
    system.nixos.label = "PalinGoneOS_${version}";
    environment.etc."palingoneos/version".text = version;

    #==========================================
    # Fond d'écran
    #==========================================
    # hiPrio : le paquet cosmic-bg fournit son propre fond par défaut au même endroit.
    environment.systemPackages = [ (lib.hiPrio brandingPackage) ];

    # Ancien emplacement, conservé pour les sessions qui y font déjà référence.
    environment.etc."palingoneos/wallpaper.png".source = ./branding/wallpaper.png;

    #============================
    # Fastfetch PalinGoneOS
    #============================
    environment.etc."palingoneos/ascii.txt".source = ./branding/ascii.txt;
    environment.etc."fastfetch/config.jsonc".text = builtins.toJSON {
      logo = {
        source = "/etc/palingoneos/ascii.txt";
        color = {
          "1" = "bright_magenta";
        };
        padding = {
          top = 0;
          left = 1;
          right = 3;
        };
      };
      display = {
        color = {
          keys = "magenta";
          title = "bright_magenta";
        };
        separator = " ➜ ";
      };
      modules = [
        "title"
        "separator"
        {
          type = "os";
          key = "OS";
          format = "PalinGoneOS ({3})";
        }
        "host"
        "kernel"
        "uptime"
        "packages"
        "shell"
        "desktop"
        "terminal"
        "cpu"
        "gpu"
        "memory"
        "break"
        "colors"
      ];
    };

    # Lancement de fastfetch à l'ouverture du terminal
    programs.bash.interactiveShellInit = ''
      if [[ $- == *i* ]]; then
        ${pkgs.fastfetch}/bin/fastfetch
      fi
    '';

    #==========================================
    # Plymouth (écran de démarrage)
    #==========================================
    boot.plymouth = {
      enable = true;
      theme = "palingoneos";
      themePackages = [
        (pkgs.stdenv.mkDerivation {
          name = "plymouth-theme-palingoneos";
          src = ./branding/plymouth;
          installPhase = ''
            mkdir -p $out/share/plymouth/themes/palingoneos
            cp -r * $out/share/plymouth/themes/palingoneos/

            # Ajustement des chemins pour le Store Nix
            sed -i "s|ImageDir=.*|ImageDir=$out/share/plymouth/themes/palingoneos|" $out/share/plymouth/themes/palingoneos/palingoneos.plymouth
            sed -i "s|ScriptFile=.*|ScriptFile=$out/share/plymouth/themes/palingoneos/palingoneos.script|" $out/share/plymouth/themes/palingoneos/palingoneos.plymouth

            # Numéro de version affiché au démarrage (défini une seule fois dans configuration.nix)
            sed -i "s|@VERSION@|${version}|" $out/share/plymouth/themes/palingoneos/palingoneos.script
          '';
        })
      ];
    };

    # Options du noyau pour un boot silencieux
    boot.kernelParams = [ "quiet" "splash" "loglevel=3" "rd.systemd.show_status=false" ];
    boot.consoleLogLevel = 0;
  };
}
