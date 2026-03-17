{ lib, stdenvNoCC, fetchpijul, python3Packages, ... }:
let
  inherit (lib)
    maintainers
    ;

  version = "26100.1742.240906-0331";

  license = {
    shortName = "microsoft-software-license";
    fullName = "Microsoft Software License Terms";
    url = "https://support.microsoft.com/en-us/windows/microsoft-software-license-terms-e26eedad-97a2-5250-2670-aad156b654bd";
    free = false;
    redistributable = false;
  };

  src = fetchpijul{
    url="https://nest.pijul.com/DzmingLi/windows-fonts";
    hash="sha256-TBqFS+qs86RyOMOori8mWKscgJ3r1IzI0VRnPpAGkw8=";
  };

  meta = {
    inherit
      license
      ;

    description = "Windows fonts distributed by Microsoft Microsoft Corporation Inc.";
    homepage = "https://learn.microsoft.com/en-us/typography/fonts/font-faq";
    maintainers = with maintainers; [ brsvh ];
    redistributable = false;
  };
in
stdenvNoCC.mkDerivation rec {
  inherit
    meta
    src
    version
    ;

  pname = "windows-fonts";

  nativeBuildInputs = [ python3Packages.fonttools ];

  preferLocalBuild = true;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/fonts/truetype
    cp -a ${src}/*.ttf $out/share/fonts/truetype/

    # Split .ttc into individual .ttf to work around Typst font selection bug
    # https://github.com/typst/typst/issues/6205
    for ttc in ${src}/*.ttc; do
      python3 -c "
from fontTools.ttLib import TTCollection
ttc = TTCollection('$ttc')
for i, font in enumerate(ttc):
    name = font['name'].getDebugName(6) or f'face{i}'
    font.save('$out/share/fonts/truetype/' + name + '.ttf')
"
    done

    runHook postInstall
  '';
}
