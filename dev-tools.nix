# Outils de développement (gh, Rust, helix...).
# Présents sur TOUTES les machines PalinGoneOS, par choix : on peut ainsi travailler
# sur le projet depuis n'importe quel ordinateur de la famille.
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
