{ lib
, stdenv
, fetchFromGitHub
, fetchgit
, cmake
, python3
, libxcrypt
, libboundscheck
, openhitls
, perl
, pcre2
, zlib
, modules ? []
, ...
}:

let
  # Build openHiTLS from source with specific configuration
  openhitlsSource = stdenv.mkDerivation {
    pname = "openhitls-source";
    version = "unstable-2024-12-31";

    src = fetchFromGitHub {
      owner = "openHiTLS";
      repo = "openHiTLS";
      rev = "c1536465be45d973bb93ae27470b219cf8a032e6";
      sha256 = "sha256-otIGrKHPtBJl3VWS012helKFCsUjxNg794agim3lcKA=";
      fetchSubmodules = true;
    };

    nativeBuildInputs = [ cmake python3 perl ];
    buildInputs = [ libboundscheck ];

    dontUseCmakeConfigure = true;

    configurePhase = ''
      python3 configure.py --enable hitls_bsl hitls_crypto hitls_tls hitls_pki hitls_auth --lib_type static --bits=64 --system=linux
    '';

    buildPhase = ''
      mkdir -p build
      cd build
      cmake ..
      make -j$NIX_BUILD_CORES
    '';

    installPhase = ''
      # Copy entire source tree for nginx build
      mkdir -p $out
      cp -r ../* $out/ || true

      # Ensure build directory exists with libraries
      mkdir -p $out/build
      cp *.a $out/build/ || true
    '';

    meta = {
      description = "OpenHiTLS source for nginx compilation";
      homepage = "https://github.com/openHiTLS/openHiTLS";
      license = lib.licenses.mulan-psl2;
    };
  };

in stdenv.mkDerivation rec {
  pname = "nginx-openhitls";
  version = "1.24.0";

  # Source from gitcode.com - use fetchgit with git protocol
  src = fetchgit {
    url = "https://gitcode.com/openHiTLS/nginx.git";
    rev = "5b8aceb6af138df09e2756d7ba383ca25673351f";
    sha256 = "sha256-ArTf0rMuNIldNtGGEGttPhY8qRtJkDM6XSSskq7yot0=";
  };

  buildInputs = [
    libxcrypt
    libboundscheck
    pcre2
    zlib
  ];

  nativeBuildInputs = [ perl ];

  prePatch = ''
    # Fix libboundscheck path in auto/lib/openhitls/conf
    sed -i 's|$OPENHITLS/platform/Secure_C/lib/libboundscheck.so|${libboundscheck}/lib/libboundscheck.so|' \
      auto/lib/openhitls/conf

    # Fix ngx_event_hitls.c bool type issue
    sed -i 's/unsigned char reused;/bool reused;/' \
      src/event/ngx_event_hitls.c
  '';

  configurePhase = ''
    cp auto/configure .
    ./configure \
      --prefix=$out \
      --with-cc-opt="-std=c99" \
      --with-ld-opt="-L${libxcrypt}/lib -lcrypt" \
      --with-http_ssl_module \
      --with-openhitls=${openhitlsSource}
  '';

  buildPhase = ''
    make -j$NIX_BUILD_CORES
  '';

  installPhase = ''
    make install

    # Create necessary directories
    mkdir -p $out/logs
    mkdir -p $out/temp/{client_body,proxy,fastcgi,uwsgi,scgi}
    mkdir -p $out/html

    # Create a basic index.html
    echo "<h1>nginx with OpenHitls</h1>" > $out/html/index.html

    # Create a sample configuration
    cat > $out/conf/nginx-openhitls.conf <<EOF
worker_processes  1;

error_log  $out/logs/error.log;
pid        $out/logs/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    access_log  $out/logs/access.log;

    client_body_temp_path $out/temp/client_body;
    proxy_temp_path $out/temp/proxy;
    fastcgi_temp_path $out/temp/fastcgi;
    uwsgi_temp_path $out/temp/uwsgi;
    scgi_temp_path $out/temp/scgi;

    sendfile        on;
    keepalive_timeout  65;

    server {
        listen       8080;
        server_name  localhost;

        location / {
            root   $out/html;
            index  index.html index.htm;
        }
    }
}
EOF
  '';

  passthru = {
    inherit modules;
  };

  meta = with lib; {
    description = "nginx with OpenHitls support for Chinese SM algorithms and TLCP protocol";
    longDescription = ''
      nginx compiled with OpenHitls library support, enabling:
      - Chinese SM2, SM3, SM4 cryptographic algorithms
      - TLCP (Transport Layer Cryptography Protocol) support
      - TLS 1.2 protocol
      - Client certificate verification
    '';
    homepage = "https://github.com/openHiTLS/nginx";
    license = licenses.bsd2;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
