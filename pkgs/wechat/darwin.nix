{
  lib,
  stdenvNoCC,
  fetchurl,
  undmg,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "wechat";
  version = "4.1.9";

  src = fetchurl {
    url = "https://dldir1v6.qq.com/weixin/Universal/Mac/WeChatMac_${finalAttrs.version}.dmg";
    hash = "sha256-zCPHmAZdpMft+PYFE4gdGF7FCN+ZAvccVQYOUW6JIk8=";
  };

  nativeBuildInputs = [ undmg ];
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/Applications
    cp -a WeChat.app $out/Applications/
    runHook postInstall
  '';

  meta = {
    description = "WeChat - Messaging and calling app";
    homepage = "https://mac.weixin.qq.com/";
    downloadPage = "https://mac.weixin.qq.com/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "aarch64-darwin" ];
  };
})
