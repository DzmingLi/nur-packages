{ pkgs, stdenv, ... }:

stdenv.mkDerivation {
  pname = "TRWUDMincho";
  version = "1.001";
  src = ./.;

  installPhase = ''
    mkdir -p $out/share/fonts/opentype/
    cp -r *.otf $out/share/fonts/opentype/

  '';

  meta = with pkgs.lib; {
    description = "TRW UD 明朝体";
    homepage = "https://zhuanlan.zhihu.com/p/9920115795";
    license = licenses.ofl; 
    platforms = platforms.all;
  };
}
