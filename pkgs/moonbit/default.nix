{ stdenv,lib,fetchzip,autoPatchelfHook, patchelf,makeWrapper,nodejs}:
let coreSrc = fetchzip{
  url = "https://cli.moonbitlang.com/cores/core-latest.tar.gz";
  sha256 = "sha256-rdNoPZvtHra7SmPv5rLyqusUkKNCCodDfifCTMqsrO0=";
};
in
stdenv.mkDerivation  {
  pname = "moonbit";
  version = "latest";
  src = fetchzip{
    url = "https://cli.moonbitlang.com/binaries/latest/moonbit-linux-x86_64.tar.gz";
    sha256 = "sha256-KifUy8fOrHFfma/tEOOGDuVGWxXFZFtg/uwv1X1mCHQ=";
    stripRoot=false;
  };
  nativeBuildInputs = [
    autoPatchelfHook # 自动修复最终安装的文件
    patchelf
    stdenv.cc.cc.lib
    makeWrapper
  ];
  buildPhase = ''
    runHook preBuild
    export HOME=$(pwd)
    export PATH=$(pwd)/bin:$PATH
    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" ./bin/moon
    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" ./bin/moonc
    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" ./bin/internal/tcc
    find ./bin -type f ! -name '*.wasm' -exec chmod +x {} +
    mkdir -p ./lib
    cp -r ${coreSrc} ./lib/core
    chmod -R u+w ./lib/core
    export MOON_HOME=$(pwd)
    pushd lib/core
    ../../bin/moon bundle --all --target-dir .
    ../../bin/moon check
    popd
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r ./* $out/
    runHook postInstall
  '';
  postFixup=''
    wrapProgram $out/bin/moon --set MOON_HOME $out
    wrapProgram $out/bin/moonbit-lsp \
      --set MOON_HOME $out \
      --prefix PATH : ${lib.makeBinPath [ nodejs ]}
  '';
  meta=with lib;{
    mainProgram="moon";
    homepage = "https://www.moonbitlang.com";
    sourceProvenance=with sourceTypes; [
      binaryNativeCode
    ];
    license=licenses.asl20;
    description = "The MoonBit Programming Languange toolchain";
  };  
}
