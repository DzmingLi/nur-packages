{ stdenv,lib,fetchzip,autoPatchelfHook, patchelf}:
let coreSrc = fetchzip{
  url="https://cli.moonbitlang.com/cores/core-latest.tar.gz";
  sha256="sha256-dte9OrgvSf48uPyxrAIswx5qfJ3A4nzWjVbJ/1QUn7Y=";
};
in
stdenv.mkDerivation  {
  name = "moonbit";
  src = fetchzip{
    url= "https://cli.moonbitlang.com/binaries/latest/moonbit-linux-x86_64.tar.gz";
    sha256="sha256-BnaV4UeQwt+nmCik+RbF3NsmBp3QIQBl533hnAglW9w=";
    stripRoot=false;
  };
  nativeBuildInputs = [
    autoPatchelfHook # 自动修复最终安装的文件
    patchelf         # 手动修复时需要用到的命令
    stdenv.cc.cc.lib
  ];
  buildPhase = ''
    runHook preBuild
    export HOME=$(pwd)
    export PATH=$(pwd)/bin:$PATH
    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" ./bin/moon
    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" ./bin/moonc
    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" ./bin/internal/tcc
    chmod +x ./bin/moon ./bin/moonc ./bin/internal/tcc
    cp -r ${coreSrc} ./core_writable
    chmod -R u+w ./core_writable
    ./bin/moon bundle --all --source-dir ./core_writable
    ./bin/moon bundle --target wasm-gc --source-dir ./core_writable --quiet
    runHook postBuild  
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib $out/include
    cp -r ./bin/* $out/bin/
    cp -r ./lib/* $out/lib/
    cp -r ./include/* $out/include/
    runHook postInstall
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
