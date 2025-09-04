{ stdenv,lib,fetchzip,autoPatchelfHook, patchelf,makeWrapper}:
let coreSrc = fetchzip{
  url = "https://cli.moonbitlang.com/cores/core-latest.tar.gz";
  sha256 = "sha256-erzNk1RA4yHBvqaF7bXLRKcVi6Rp4iPNHqBmuSXwChs=";
};
in
stdenv.mkDerivation  {
  name = "moonbit";
  src = fetchzip{
    url = "https://cli.moonbitlang.com/binaries/latest/moonbit-linux-x86_64.tar.gz";
    sha256 = "sha256-2xg+QdRw84ETL8ty/Cstjl0ZRzSfQ2FTpbol0KlZH8A=";
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
    chmod +x ./bin/*
    cp -r ${coreSrc} ./core_writable
    chmod -R u+w ./core_writable
    ./bin/moon bundle --all --source-dir ./core_writable
    ./bin/moon bundle --target wasm-gc --source-dir ./core_writable --quiet
    runHook postBuild  
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r ./* $out/
    mkdir -p $out/lib
    mv ./core_writable $out/lib/core
    runHook postInstall
  '';
  postFixup=''
    wrapProgram $out/bin/moon --set MOON_HOME $out
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
