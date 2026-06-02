{ stdenv, callPackage, fluent-reader }:

# darwin（仅 Apple Silicon）走官方 GitHub release 的 mac .app（darwin.nix）；
# linux 直接用 nixpkgs 的 fluent-reader。
if stdenv.hostPlatform.isDarwin
then callPackage ./darwin.nix { }
else fluent-reader
