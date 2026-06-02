{
  lib,
  stdenvNoCC,
  fetchurl,
  undmg,
}:

# MakeMKV macOS 官方 .app，从官网 dmg 解包。
# 版本/hash 由 lee 手动维护：
#   最新版见 https://www.makemkv.com/download/（页面有 "MakeMKV x.y.z"）
#   直链形如 https://www.makemkv.com/download/makemkv_v<ver>_osx.dmg（版本在文件名里）
#   `nix store prefetch-file <url>` 取 sha256
# dmg 是 universal（Intel+Apple Silicon）；这里只声明 aarch64-darwin。
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "makemkv";
  version = "1.18.3";

  src = fetchurl {
    url = "https://www.makemkv.com/download/makemkv_v${finalAttrs.version}_osx.dmg";
    hash = "sha256-K6XZqeKBAW9Y9U3iAcKhHaDh9bEtG8hUU3RzVot97Vs=";
  };

  sourceRoot = ".";
  nativeBuildInputs = [ undmg ];

  installPhase = ''
    runHook preInstall
    app=$(find . -maxdepth 2 -name 'MakeMKV.app' -type d | head -1)
    if [ -z "$app" ]; then
      echo "MakeMKV.app not found after undmg" >&2
      exit 1
    fi
    mkdir -p "$out/Applications"
    cp -r "$app" "$out/Applications/"
    runHook postInstall
  '';

  meta = {
    description = "MakeMKV - DVD/Blu-ray 转 MKV (macOS Apple Silicon, official .app)";
    homepage = "https://www.makemkv.com/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "aarch64-darwin" ];
  };
})
