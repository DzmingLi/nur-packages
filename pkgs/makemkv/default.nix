{ stdenv, callPackage, makemkv }:

# darwin（仅 Apple Silicon）走官网 mac .app（darwin.nix）；
# linux 直接用 nixpkgs 的 makemkv。
if stdenv.hostPlatform.isDarwin
then callPackage ./darwin.nix { }
else makemkv
