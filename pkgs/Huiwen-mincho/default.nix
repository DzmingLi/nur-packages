{ pkgs, stdenv,fetchpijul, ... }:

stdenv.mkDerivation {
  pname = "Huiwen-mincho";
  version = "1.001";
  src = fetchpijul{
    url="https://nest.pijul.com/DzmingLi/Huiwen-mincho";
    hash="sha256-rKNCXap4+Zd9KAJ3BbDQjT5k8WxQghly/sllV3dr5DY=";
  };

  installPhase = ''
    mkdir -p $out/share/fonts/opentype/
    cp -r *.otf $out/share/fonts/opentype/

  '';

  meta = with pkgs.lib; {
    description = "汇文明朝体";
    homepage = "https://zhuanlan.zhihu.com/p/12669052378";
    license = licenses.ofl;
    platforms = platforms.all;
  };
}
