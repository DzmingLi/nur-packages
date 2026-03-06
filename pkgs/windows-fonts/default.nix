{ lib, stdenvNoCC,fetchpijul, ... }:
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

  preferLocalBuild = true;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/fonts/truetype
    cp -a ${src}/truetype/. $out/share/fonts/truetype/

    runHook postInstall
  '';
}
