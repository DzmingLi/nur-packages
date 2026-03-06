# This file describes your repository contents.
# It should return a set of nix derivations
# and optionally the special attributes `lib`, `modules` and `overlays`.
# It should NOT import <nixpkgs>. Instead, you should take pkgs as an argument.
# Having pkgs default to <nixpkgs> is fine though, and it lets you use short
# commands such as:
#     nix-build -A mypackage

{ pkgs ? import <nixpkgs> { }
, haumea ? { lib = import (builtins.fetchTarball "https://github.com/nix-community/haumea/archive/6006638de0f991dc33d0590819f58d09bec27379.tar.gz") {}; }
}:

{
  # The `lib`, `modules`, and `overlays` names are special
  lib = import ./lib { inherit pkgs; }; # functions
  modules = import ./modules; # NixOS modules
  overlays = import ./overlays; # nixpkgs overlays
} // builtins.mapAttrs (_: v: v.default) (haumea.lib.load {
  src = ./pkgs;
  inputs = builtins.removeAttrs pkgs [ "self" "super" "root" ];
  loader = haumea.lib.loaders.callPackage;
})
