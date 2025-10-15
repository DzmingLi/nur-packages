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
, libnotify
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
, libindicator-gtk3
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
    libnotify
    libpulseaudio
    libuuid
    libsecret
    libxkbcommon
    mesa
    nspr
    nss
    pango
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
    libindicator-gtk3
  ];

  # Ignore missing dependencies that are bundled or not needed
  autoPatchelfIgnoreMissingDeps = [
    "libcrypto.so.1.0.0"
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
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}:$out/share/wework" \
      --prefix PATH : "${lib.makeBinPath [ xorg.xdpyinfo ]}" \
      --set packagename wwlocal \
      --chdir "$out/share/wework" \
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
