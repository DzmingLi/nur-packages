{ lib
, stdenv
, fetchFromGitHub
, cmake
, python3
, libboundscheck
}:

stdenv.mkDerivation rec {
  pname = "openhitls";
  version = "unstable-2024-12-31";

  src = fetchFromGitHub {
    owner = "openHiTLS";
    repo = "openHiTLS";
    rev = "main";
    sha256 = "sha256-6LqOPGnUx9mr1akApZf97kfNp0nEhrK9SRMY0hV+ZaI=";
  };

  nativeBuildInputs = [
    cmake
    python3
  ];

  buildInputs = [
    libboundscheck
  ];

  NIX_CFLAGS_COMPILE = [
    "-Wno-error=stringop-overflow"
  ];

  preConfigure = ''
    python3 configure.py --enable all --bits 64
  '';

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
  ];

  postInstall = ''
    # Install config header files needed for compiling against openHiTLS
    mkdir -p $out/include/hitls/config

    # The config files are in the original source directory
    cd "$NIX_BUILD_TOP/$sourceRoot" || cd "$NIX_BUILD_TOP/source" || true

    if [ -d "config/macro_config" ] && [ -n "$(ls config/macro_config/*.h 2>/dev/null)" ]; then
      cp config/macro_config/*.h $out/include/hitls/config/
    fi
  '';

  meta = with lib; {
    description = "Highly efficient and agile open-source SDK for cryptography and transport layer security";
    longDescription = ''
      openHiTLS is an open-source SDK for cryptography and transport layer security.
      It provides a highly modular architecture with configurable components including:
      - Base Support Layer (BSL)
      - Cryptography (crypto)
      - TLS/DTLS protocols (supports TLS1.3, TLCP, DTLS)
      - PKI (Public Key Infrastructure)
      - Authentication (Auth)

      Supports post-quantum cryptography algorithms like ML-DSA and ML-KEM,
      as well as traditional algorithms like AES, SM4, RSA, and ECDSA.
      Performance optimized for ARM and x86 architectures.
    '';
    homepage = "https://github.com/openHiTLS/openHiTLS";
    license = licenses.mulan-psl2;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
