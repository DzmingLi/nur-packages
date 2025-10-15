{ stdenv
, lib
, fetchurl
, autoPatchelfHook
, makeWrapper
, alsa-lib
, at-spi2-atk
, at-spi2-core
, atk
, cairo
, cups
, dbus
, expat
, fontconfig
, freetype
, gdk-pixbuf
, glib
, gtk3
, libappindicator-gtk3
, libdrm
, libglvnd
, libnotify
, libpng
, libpulseaudio
, libuuid
, libsecret
, libxkbcommon
, mesa
, nspr
, nss
, pango
, systemd
, xorg
, zlib
, libindicator-gtk3
, curl
, openssl_1_1
}:

stdenv.mkDerivation rec {
  pname = "wework";
  version = "3.1.0.198N02-1";

  src = fetchurl {
    url = "https://dldir1.qq.com/wework/weworklocalapp/SVsEVVSIWIZPEAKypCsjps29acDcEcVUYXawZ1Ty56A/signed_weworklocal_3.1.0.198N02.x86.UOSv20.deb";
    hash = "sha256-aB71aecXucdm8ENNNlKT5gW/eiuSN4QlmDn6SA8S8mQ=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libappindicator-gtk3
    libdrm
    libglvnd
    libnotify
    libpng
    libpulseaudio
    libuuid
    libsecret
    libxkbcommon
    mesa
    nspr
    nss
    pango
    curl
    stdenv.cc.cc.lib
    systemd
    xorg.libX11
    xorg.libxcb
    xorg.libXcomposite
    xorg.libXcursor
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXi
    xorg.libXrandr
    xorg.libXrender
    xorg.libXScrnSaver
    xorg.libxshmfence
    xorg.libXtst
    zlib
    libindicator-gtk3
    openssl_1_1
  ];

  # Ignore missing dependencies that are bundled or not needed
  autoPatchelfIgnoreMissingDeps = [
    "libcrypto.so.1.0.0"
    "libssl.so.1.1"
    "libcrypto.so.1.1"
  ];

  unpackPhase = ''
    runHook preUnpack
    ar x $src
    tar --no-same-owner --no-same-permissions -xJf data.tar.xz
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share
    cp -r opt/apps/WXWorkLocalPro/files $out/share/wework

    # Remove bundled libraries that are safe to replace (stable ABI, no allocator issues)
    rm -f $out/share/wework/libz.so*
    rm -f $out/share/wework/libpng16.so*
    # Keep bundled libcurl, libstdc++, and OpenSSL 1.1 for ABI compatibility with vendor binaries
    # Keep protobuf as bundled for ABI compatibility (app requires v20)

    # Replace bundled EGL/GLES libraries with system libraries
    rm -f $out/share/wework/libEGL.so*
    rm -f $out/share/wework/libGLESv2.so*
    ln -s ${libglvnd}/lib/libEGL.so.1 $out/share/wework/libEGL.so
    ln -s ${libglvnd}/lib/libGLESv2.so.2 $out/share/wework/libGLESv2.so

    # Build curl safeguard preload that duplicates string options
    $CC -shared -fPIC -O2 \
      -I${curl.dev}/include \
      -o $out/share/wework/libcurl-guard.so ${./malloc-interceptor.c} \
      -ldl

    # Build allocator guard to ignore bogus frees in vendor protobuf
    $CC -shared -fPIC -O2 \
      -o $out/share/wework/libfree-guard.so ${./free-guard.c} \
      -ldl -pthread

    # Install desktop file
    mkdir -p $out/share/applications
    cp opt/apps/WXWorkLocalPro/entries/applications/wwlocal.desktop $out/share/applications/wework.desktop
    substituteInPlace $out/share/applications/wework.desktop \
      --replace-fail '"/opt/apps/WXWorkLocalPro/files/wwlocal.sh"' "$out/bin/wework" \
      --replace-fail "Icon=wwlocal" "Icon=wework"

    # Install icons
    mkdir -p $out/share/icons/hicolor/512x512/apps
    cp opt/apps/WXWorkLocalPro/entries/icons/hicolor/512x512/apps/wwlocal.png \
      $out/share/icons/hicolor/512x512/apps/wework.png

    # Create wrapper script
    mkdir -p $out/bin
    makeWrapper $out/share/wework/wwlocal $out/bin/wework \
      --prefix LD_LIBRARY_PATH : "$out/share/wework:${lib.makeLibraryPath buildInputs}" \
      --prefix PATH : "${lib.makeBinPath [ xorg.xdpyinfo ]}" \
      --set LD_PRELOAD "$out/share/wework/libfree-guard.so:$out/share/wework/libcurl-guard.so" \
      --set QTWEBENGINE_DISABLE_SANDBOX 1 \
      --set packagename wwlocal \
      --chdir "$out/share/wework" \
      --add-flags "--disable-setuid-sandbox" \
      --add-flags "--no-sandbox" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"

    runHook postInstall
  '';

  meta = with lib; {
    description = "企业微信 (WeCom / WeChat Work)";
    homepage = "https://work.weixin.qq.com/";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = [ ];
    mainProgram = "wework";
  };
}
