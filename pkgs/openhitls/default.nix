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
    sha256 = "sha256-I9/3POBnh/B0FeOmRZTP6ZiS99QN6Bhgsu070e67Tfs=";
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
    python3 configure.py --enable hitls_bsl hitls_crypto hitls_tls hitls_pki hitls_auth --bits 64
    ls -la config/macro_config/ || echo "Config dir not found"
  '';

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
  ];

  postInstall = ''
    # Install config header files needed for compiling against openHiTLS
    mkdir -p $out/include/hitls/config

    # Try to find config files in source directory
    if [ -d "$sourceRoot/config/macro_config" ]; then
      echo "Installing config headers from $sourceRoot/config/macro_config"
      cp $sourceRoot/config/macro_config/*.h $out/include/hitls/config/ 2>/dev/null || true
    elif [ -d "config/macro_config" ]; then
      echo "Installing config headers from config/macro_config"
      cp config/macro_config/*.h $out/include/hitls/config/ 2>/dev/null || true
    else
      echo "Warning: config/macro_config headers not found"
    fi

    ls -la $out/include/hitls/config/ || true
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
