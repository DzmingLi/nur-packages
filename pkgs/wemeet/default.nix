{ stdenv, callPackage }:

# darwin（仅 Apple Silicon）走官方 mac .app（darwin.nix）；
# linux 走自打包的 wayland 原生版（linux.nix）。
if stdenv.hostPlatform.isDarwin
then callPackage ./darwin.nix { }
else callPackage ./linux.nix { }
