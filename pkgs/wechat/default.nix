{ stdenv, callPackage, wechat }:

# On darwin we have no custom patches, so let the overlay be a no-op there
# (returning the upstream nixpkgs wechat). On linux we apply our own patches
# (libtiff, fcitx env in .desktop, direct CDN URL).
if stdenv.hostPlatform.isDarwin
then wechat
else callPackage ./linux.nix { }
