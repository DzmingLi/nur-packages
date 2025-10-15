# This file describes your repository contents.
# It should return a set of nix derivations
# and optionally the special attributes `lib`, `modules` and `overlays`.
# It should NOT import <nixpkgs>. Instead, you should take pkgs as an argument.
# Having pkgs default to <nixpkgs> is fine though, and it lets you use short
# commands such as:
#     nix-build -A mypackage

{ pkgs ? import <nixpkgs> { } }:

{
  # The `lib`, `modules`, and `overlays` names are special
  lib = import ./lib { inherit pkgs; }; # functions
  modules = import ./modules; # NixOS modules
  overlays = import ./overlays; # nixpkgs overlays

  moonbit = pkgs.callPackage ./pkgs/moonbit { };
  waydroid-script = pkgs.callPackage ./pkgs/waydroid-script { };
  # shiroa = pkgs.callPackage ./pkgs/shiroa { };
  huiwen-mincho = pkgs.callPackage ./pkgs/huiwen-mincho { };
  genryumin = pkgs.callPackage ./pkgs/genryumin { };
  TRWUDMincho = pkgs.callPackage ./pkgs/TRWUDMincho { };
  libboundscheck = pkgs.callPackage ./pkgs/libboundscheck { };
  openhitls = pkgs.callPackage ./pkgs/openhitls {
    libboundscheck = pkgs.callPackage ./pkgs/libboundscheck { };
  };
  nginx-openhitls = pkgs.callPackage ./pkgs/nginx-openhitls {
    libboundscheck = pkgs.callPackage ./pkgs/libboundscheck { };
    openhitls = pkgs.callPackage ./pkgs/openhitls {
      libboundscheck = pkgs.callPackage ./pkgs/libboundscheck { };
    };
  };
}
