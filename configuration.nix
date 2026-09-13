# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

#========================================================================================================
#                                            PalinGoneOS
#========================================================================================================


{ config, lib, pkgs, ... }:

 
{
 # Activation de Nix Experimental
 nix.settings.experimental-features = [
  "nix-command"
  "flakes"
 ];




 #GitHub Dépot
 nix.extraOptions = "
   access-tokens = github.com=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
 ";

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
 
 imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];
  # Paquet Non Libre
  nixpkgs.config.allowUnfree = true;
  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 8 ; 
  networking.hostName = "palingoneos"; # Define your hostname.

  # Configure network connections interactively with nmcli or nmtui.
  networking.networkmanager.enable = true;
  # Set your time zone.
  time.timeZone = "Europe/Paris";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = "fr_FR.UTF-8";
  console = {
  #   font = "Lat2-Terminus16";
    keyMap = "fr";
  #   useXkbConfig = true; # use xkb.options in tty.
  };
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "fr_FR.UTF-8";
    LC_IDENTIFICATION = "fr_FR.UTF-8";
    LC_MEASUREMENT = "fr_FR.UTF-8";
    LC_MONETARY = "fr_FR.UTF-8";
    LC_NAME = "fr_FR.UTF-8";
    LC_NUMERIC = "fr_FR.UTF-8";
    LC_PAPER = "fr_FR.UTF-8";
    LC_TELEPHONE = "fr_FR.UTF-8";
    LC_TIME = "fr_FR.UTF-8";
  };
  # Enable the X11 windowing system.
  # services.xserver.enable = true;


  

  # Configure keymap in X11
  services.xserver.xkb.layout = "fr";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # services.pulseaudio.enable = true;
  # OR
  # services.pipewire = {
  #   enable = true;
  #   pulse.enable = true;
  # };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.palingone = {
    isNormalUser = true;
    description = "PalinGone";
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "palingone" ;
  # Enable ‘sudo’ for the user.
  #   packages = with pkgs; [
  #     tree
  #   ];
  };
  security.sudo = {
   enable = true;
   wheelNeedsPassword = true;
   extraRules = [
     {
       groups = [ "wheel" ];
       commands = [
         {
           command = "/run/current-system/sw/bin/nixos-rebuild";
           options = [ "NOPASSWD" ];
         }
       ];
     }
   ];
 };
  # Navigateur.
    programs.firefox.enable = true;

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
   environment.systemPackages = with pkgs; [
    # Systeme de base
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    nano
    git
    curl
    htop
    fastfetch
    gh
    htop

    # Suite Bureautique    
    libreoffice

    # Compatibilité Windows et Jeux
    winetricks
    wine
    lutris

    # Environnement de bureau Cosmic pour PalinGoneOS
    cosmic-store
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .



  #==============================================================================================================================
  # Information Distribution
  #==============================================================================================================================


  system.nixos.distroName = "PalinGoneOS";
  system.nixos.label = "PalinGoneOS_0.30.9";
  system.stateVersion = "26.05";

  #==========================================
  # Plymouth
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
        '';
      })
    ];
   };
  
  # Options du noyau pour un boot silencieux
  boot.kernelParams = [ "quiet" "splash" "loglevel=3" "rd.systemd.show_status=false" ];
  boot.consoleLogLevel = 0;
  
  
  
# Fond d'écran PalinGoneOS
  environment.etc."backgrounds/palingoneos-wallpaper.png".source = ./branding/wallpaper.png;


  # COSMIC Desktop
  services.displayManager.cosmic-greeter.enable = true;
  services.desktopManager.cosmic.enable = true;



  # ==========================
  # FLATPAK / FLATHUB
  # ==========================
  services.flatpak.enable = true;
  
  # Depot Officiel PalinGoneOS
  services.flatpak.remotes = [
    #Flathub
    {
      name = "flathub";
      location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
    }
   # Applets COSMIC
   {
    name = "cosmic";
    location = "https://apt.pop-os.org/cosmic/cosmic.flatpakrepo";
   }
  ];

  
  # STEAM
  programs.steam.enable = true;

  # Support Graphique
  hardware.graphics.enable = true;

  # Lancement de fastfetch à l'ouverture du terminal
  programs.bash = {
    interactiveShellInit = "
      if [[ $- == *i* ]]; then
	${pkgs.fastfetch}/bin/fastfetch
      fi
   ";
  };

}

