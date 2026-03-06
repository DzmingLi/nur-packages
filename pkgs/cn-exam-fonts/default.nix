{ pkgs, stdenv,fetchpijul, ... }:

stdenv.mkDerivation {
  pname = "cn-exam-fonts";
  version = "1.0.0";
  src = fetchpijul{
    url="https://nest.pijul.com/DzmingLi/cn-exam-fonts";
    hash="sha256-HvnvEnOVSRcL5tq7tREiU65ox4q7j4KOmqtQFG1f7dw=";
  };

  installPhase = ''
    mkdir -p $out/share/fonts/truetype/
    cp -r *.ttf $out/share/fonts/truetype/
  '';

  meta = with pkgs.lib; {
    description = "中国教育部考试通常使用的字体：方正书宋和方正黑体";
    license = licenses.unfree;
    platforms = platforms.all;
  };
}
