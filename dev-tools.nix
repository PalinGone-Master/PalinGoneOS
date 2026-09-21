# Outils de développement — pour la machine du créateur uniquement.
# Ce module ne doit PAS être importé dans la configuration de l'ISO « famille ».
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    gh
    rustc
    cargo
    just
    cargo-generate
    helix
    gcc
    pkg-config
    libxkbcommon.dev
  ];
}
