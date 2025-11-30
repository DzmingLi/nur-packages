{ stdenv
, lib
, dpkg
, autoPatchelfHook
, makeWrapper
, alsa-lib
, at-spi2-atk
, at-spi2-core
, cairo
, cups
, dbus
, dbus-glib
, expat
, glib
, gtk2
, gtk3
, libdrm
, libxkbcommon
, mesa
, nspr
, nss
, pango
, xorg
}:

stdenv.mkDerivation rec {
  pname = "easyconnect";
  version = "7.6.7.3";

  src = ./EasyConnect_x64_7_6_7_3.deb;

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    dbus-glib
    expat
    glib
    gtk2
    gtk3
    libdrm
    libxkbcommon
    mesa
    nspr
    nss
    pango
    stdenv.cc.cc.lib
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
    xorg.libxshmfence
    xorg.libXtst
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x $src .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt $out/bin $out/share

    # 复制应用文件
    cp -r usr/share/sangfor/EasyConnect $out/opt/easyconnect

    # 设置可执行权限
    chmod +x $out/opt/easyconnect/EasyConnect

    # 复制桌面文件和图标
    cp -r usr/share/applications $out/share/
    cp -r usr/share/pixmaps $out/share/

    # 修改桌面文件中的路径
    substituteInPlace $out/share/applications/EasyConnect.desktop \
      --replace-fail '/usr/share/sangfor/EasyConnect/EasyConnect' "$out/bin/easyconnect"

    # 创建启动脚本
    makeWrapper $out/opt/easyconnect/EasyConnect $out/bin/easyconnect \
      --chdir $out/opt/easyconnect \
      --add-flags "--enable-transparent-visuals --disable-gpu" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Sangfor EasyConnect VPN client";
    homepage = "https://www.sangfor.com.cn";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = [ ];
    mainProgram = "easyconnect";
  };
}
