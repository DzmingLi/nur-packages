# You can use this file as a nixpkgs overlay. This is useful in the
# case where you don't want to add the whole NUR namespace to your
# configuration.

self: super:
let
  isReserved = n: n == "lib" || n == "overlays" || n == "modules";
  nameValuePair = n: v: { name = n; value = v; };
  nurAttrs = import ./default.nix { pkgs = super; };
  emacsPackageDirs =
    super.lib.filterAttrs (_: type: type == "directory")
      (builtins.readDir ./pkgs/emacsPackages);
  emacsPackageOverrides = epkgs:
    builtins.mapAttrs
      (name: _: epkgs.callPackage (./pkgs/emacsPackages + "/${name}") {
        tree-sitter = super.tree-sitter;
      })
      emacsPackageDirs;

in
(builtins.listToAttrs
  (map (n: nameValuePair n nurAttrs.${n})
    (builtins.filter (n: !isReserved n)
      (builtins.attrNames nurAttrs))))
// {
  emacsPackagesFor = emacs:
    (super.emacsPackagesFor emacs).overrideScope
      (efinal: _eprev: emacsPackageOverrides efinal);
  emacsPackages =
    super.emacsPackages.overrideScope
      (efinal: _eprev: emacsPackageOverrides efinal);
}
