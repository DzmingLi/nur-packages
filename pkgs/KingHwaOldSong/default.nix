{ pkgs, stdenv,fetchpijul, ... }:

stdenv.mkDerivation {
  pname = "KingHwaOldSong";
  version = "3.0";
  src = fetchpijul{
    url="https://nest.pijul.com/DzmingLi/KingHwaOldSong";
    hash="sha256-aP3zbu+H2U4cAJbjPgR/91sA+bJfth9yBlLx1FboZp4=";
  };

  installPhase = ''
    mkdir -p $out/share/fonts/truetype/
    cp -r *.ttf $out/share/fonts/truetype/
  '';

  meta = with pkgs.lib; {
    description = "京华老宋体";
    homepage = "https://zhuanlan.zhihu.com/p/1915922891633043436";
    license = licenses.ofl;
    platforms = platforms.all;
  };
}
