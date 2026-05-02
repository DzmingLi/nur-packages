{ stdenv, lib, fetchzip, autoPatchelfHook, patchelf, makeWrapper, nodejs }:
let
  sources = {
    "x86_64-linux" = {
      url = "https://cli.moonbitlang.com/binaries/latest/moonbit-linux-x86_64.tar.gz";
      sha256 = "sha256-KifUy8fOrHFfma/tEOOGDuVGWxXFZFtg/uwv1X1mCHQ=";
    };
    "aarch64-darwin" = {
      url = "https://cli.moonbitlang.com/binaries/latest/moonbit-darwin-aarch64.tar.gz";
      sha256 = "sha256-vEA5h54nujvBB4xk788IwFw2wbHA4e7WYxqrPhLuV7M=";
    };
  };
  source = sources.${stdenv.hostPlatform.system} or (throw "moonbit: unsupported system ${stdenv.hostPlatform.system}");
  coreSrc = fetchzip {
    url = "https://cli.moonbitlang.com/cores/core-latest.tar.gz";
    sha256 = "sha256-rdNoPZvtHra7SmPv5rLyqusUkKNCCodDfifCTMqsrO0=";
  };
in
stdenv.mkDerivation {
  pname = "moonbit";
  version = "latest";
  src = fetchzip {
    inherit (source) url sha256;
    stripRoot = false;
  };
  nativeBuildInputs = [
    makeWrapper
  ] ++ lib.optionals stdenv.hostPlatform.isLinux [
    autoPatchelfHook
    patchelf
    stdenv.cc.cc.lib
  ];
  buildPhase = ''
    runHook preBuild
    export HOME=$(pwd)
    export PATH=$(pwd)/bin:$PATH
  '' + lib.optionalString stdenv.hostPlatform.isLinux ''
    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" ./bin/moon
    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" ./bin/moonc
    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" ./bin/internal/tcc
  '' + ''
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
  postFixup = ''
    wrapProgram $out/bin/moon --set MOON_HOME $out
    wrapProgram $out/bin/moonbit-lsp \
      --set MOON_HOME $out \
      --prefix PATH : ${lib.makeBinPath [ nodejs ]}
  '';
  meta = with lib; {
    mainProgram = "moon";
    homepage = "https://www.moonbitlang.com";
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    license = licenses.asl20;
    description = "The MoonBit Programming Language toolchain";
    platforms = [ "x86_64-linux" "aarch64-darwin" ];
  };
}
