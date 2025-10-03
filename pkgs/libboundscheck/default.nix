{ lib
, stdenv
, fetchgit
}:

stdenv.mkDerivation rec {
  pname = "libboundscheck";
  version = "1.1.16";

  src = fetchgit {
    url = "https://gitee.com/openeuler/libboundscheck.git";
    rev = "v${version}";
    sha256 = "sha256-cjztZQ1MbsMqWIi7Q2xAjzHX9/pIORy67ZX8dOUDa2g=";
  };

  makeFlags = [ "CC=${stdenv.cc.targetPrefix}cc" ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib
    mkdir -p $out/include

    cp lib/libboundscheck.so $out/lib/
    cp include/*.h $out/include/

    runHook postInstall
  '';

  meta = with lib; {
    description = "Bounds checking interfaces for C";
    longDescription = ''
      A C library that implements enhanced safety functions following the
      C11 Annex K (Bounds-checking interfaces) standard. Includes memory
      and string operation functions with enhanced safety checks.
    '';
    homepage = "https://gitee.com/openeuler/libboundscheck";
    license = licenses.mulan-psl2;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
