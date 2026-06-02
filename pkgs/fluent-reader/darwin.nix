{
  lib,
  stdenvNoCC,
  fetchurl,
  undmg,
}:

# Fluent Reader macOS 官方 .app，从 GitHub release 的 dmg 解包。
# 版本/hash 由 lee 手动维护：
#   最新版见 https://github.com/yang991178/fluent-reader/releases
#   直链形如 .../download/v<ver>/Fluent.Reader.<ver>.dmg
#   `nix store prefetch-file <url>` 取 sha256
# dmg 是 Electron 通用包（universal），arm64/x86_64 都能跑；这里只声明 aarch64-darwin。
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fluent-reader";
  version = "1.2.2";

  src = fetchurl {
    url = "https://github.com/yang991178/fluent-reader/releases/download/v${finalAttrs.version}/Fluent.Reader.${finalAttrs.version}.dmg";
    hash = "sha256-+WYRbbKthVww1ccQ7DydhAjYZ7gcoVa2OVOQEOVq2QY=";
  };

  sourceRoot = ".";
  nativeBuildInputs = [ undmg ];

  installPhase = ''
    runHook preInstall
    # 只取顶层主 bundle，排除 Electron 内嵌的 Helper (GPU/Renderer/Plugin) .app
    app=$(find . -maxdepth 2 -name 'Fluent Reader.app' -type d | head -1)
    if [ -z "$app" ]; then
      echo "Fluent Reader.app not found after undmg" >&2
      exit 1
    fi
    mkdir -p "$out/Applications"
    cp -r "$app" "$out/Applications/"
    runHook postInstall
  '';

  meta = {
    description = "Fluent Reader - 跨平台 RSS 阅读器 (macOS, official .app)";
    homepage = "https://github.com/yang991178/fluent-reader";
    license = lib.licenses.bsd3;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "aarch64-darwin" ];
  };
})
