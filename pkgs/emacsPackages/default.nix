{ pkgs ? import <nixpkgs> { } }:

builtins.mapAttrs
  (name: _: pkgs.callPackage (./. + "/${name}") { })
  (pkgs.lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./.))
