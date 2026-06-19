{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  # NEEDED 直接依赖
  glib,
  gtk3,
  pango,
  cairo,
  gdk-pixbuf,
  atk,
  harfbuzz,
  fontconfig,
  libepoxy,
  alsa-lib,
  libnotify,
  zlib,
  # media_kit 在运行时 dlopen libmpv.so.2（autoPatchelf 抓不到，放 runtimeDependencies）
  mpv-unwrapped,
}:

# Musly —— Subsonic 兼容服务器的 Flutter 音乐客户端。
# 上游 GitHub release 直接提供 Flutter Linux bundle（musly-linux-x64.tar.gz），
# 从源码用 Nix 跑 flutter build 极其麻烦，这里直接 autoPatchelf 预编译产物。
# 版本/hash 由 lee 手动维护：最新版见 https://github.com/dddevid/Musly/releases
stdenv.mkDerivation (finalAttrs: {
  pname = "musly";
  version = "1.0.13";

  src = fetchurl {
    url = "https://github.com/dddevid/Musly/releases/download/v${finalAttrs.version}/musly-linux-x64.tar.gz";
    hash = "sha256-3z134fVfUadIlFdtN+Z+bOsy4SmQcQe9QKnyET3aS6k=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = [
    glib
    gtk3
    pango
    cairo
    gdk-pixbuf
    atk
    harfbuzz
    fontconfig
    libepoxy
    alsa-lib
    libnotify
    zlib
    stdenv.cc.cc.lib # libstdc++.so.6 / libgcc_s.so.1
  ];

  # media_kit 通过 FFI dlopen libmpv.so.2；autoPatchelfHook 把它追加进所有
  # ELF 的 RPATH，确保运行时能找到。
  runtimeDependencies = [ (lib.getLib mpv-unwrapped) ];

  installPhase = ''
    runHook preInstall

    install -dm755 "$out/share/musly"
    cp -r musly lib data "$out/share/musly/"
    chmod +x "$out/share/musly/musly"

    # 主程序通过 $ORIGIN/lib 找到捆绑的 Flutter 插件 .so，保留原 RPATH 即可。
    # 但 media_kit 通过 dart:ffi 的 DynamicLibrary.open("libmpv.so.2") 裸 soname
    # dlopen libmpv —— 这不走可执行文件的 RPATH，必须靠 LD_LIBRARY_PATH。
    install -dm755 "$out/bin"
    makeWrapper "$out/share/musly/musly" "$out/bin/musly" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ mpv-unwrapped ]}"

    # 桌面入口 + 图标（图标取自 bundle 内的 logo.png）
    install -Dm644 data/flutter_assets/assets/logo.png \
      "$out/share/icons/hicolor/512x512/apps/musly.png"

    runHook postInstall
  '';

  postFixup = ''
    mkdir -p "$out/share/applications"
    cat > "$out/share/applications/musly.desktop" <<EOF
    [Desktop Entry]
    Type=Application
    Name=Musly
    Comment=Music streaming client for Subsonic-compatible servers
    Exec=musly %U
    Icon=musly
    Terminal=false
    Categories=AudioVideo;Audio;Player;
    StartupWMClass=musly
    EOF
  '';

  meta = {
    description = "Flutter music streaming client for Subsonic-compatible servers";
    homepage = "https://github.com/dddevid/Musly";
    license = lib.licenses.cc-by-nc-sa-40;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "musly";
    platforms = [ "x86_64-linux" ];
  };
})
