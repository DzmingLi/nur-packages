{
  lib,
  stdenvNoCC,
  fetchurl,
  undmg,
}:

# 企业微信 / WeCom macOS (Apple Silicon) 官方 .app，直接从官网 dmg 解包。
# 版本/hash 由 lee 手动维护：
#   1. 打开 https://work.weixin.qq.com/#indexDownload
#   2. mac arm64 入口是 commdownload?platform=mac_arm64，它 302 到
#      https://dldir1.qq.com/foxmail/wecom-mac/updatebzl/WeCom_<ver>_Apple.dmg
#      （URL 干净、版本在文件名里，无轮换 hash —— 直接 curl -IL 跟重定向即可拿到）
#   3. `nix store prefetch-file <url>` 取 sha256
# 仅出 aarch64-darwin（Intel mac 用不到，不打包）。
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "wxwork";
  version = "5.0.8.99856";

  src = fetchurl {
    url = "https://dldir1.qq.com/foxmail/wecom-mac/updatebzl/WeCom_${finalAttrs.version}_Apple.dmg";
    hash = "sha256-kTt9K5da353EK4DSH23cJUpOZMWzwB/lW8WNc2h1By8=";
  };

  sourceRoot = ".";
  nativeBuildInputs = [ undmg ];

  installPhase = ''
    runHook preInstall
    app=$(find . -maxdepth 2 -name '企业微信.app' -type d | head -1)
    if [ -z "$app" ]; then
      echo "企业微信.app not found after undmg" >&2
      exit 1
    fi
    mkdir -p "$out/Applications"
    cp -r "$app" "$out/Applications/"
    runHook postInstall
  '';

  meta = {
    description = "Tencent WeCom / 企业微信 (macOS Apple Silicon, official .app)";
    homepage = "https://work.weixin.qq.com/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "aarch64-darwin" ];
  };
})
