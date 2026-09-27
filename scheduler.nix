{ config, lib, pkgs, ... }:

{
  services.scx = {
    enable = true;
    scheduler = "scx_lavd"; # scx_bpfland = alternative plus généraliste
  };
}
