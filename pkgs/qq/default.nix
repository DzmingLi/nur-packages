{
  lib,
  qq,
  fetchurl,
}:

# Bump to upstream 3.2.28 (2026-04-29). Two patches on top of nixpkgs:
#   1. Source override — newer than what nixpkgs currently pins.
#   2. Keep the bundled sharp-lib: 3.2.28's sharp-linux-x64.node needs vips_g_once,
#      a symbol missing from the libvips currently in nixpkgs.
qq.overrideAttrs (old: {
  version = "3.2.28-2026-04-29";
  src = fetchurl {
    url = "https://dldir1v6.qq.com/qqfile/qq/QQNT/Linux/QQ_3.2.28_260429_amd64_01.deb";
    hash = "sha256-aOeddKzcDFpw76jqHYtkELUaIZBoQ3dNOC8y4OOh8Nc=";
  };
  installPhase = lib.replaceStrings
    [ "rm -r $out/opt/QQ/resources/app/sharp-lib" ]
    [ ": # keep bundled sharp-lib for vips_g_once" ]
    old.installPhase;
})
