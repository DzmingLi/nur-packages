{ stdenv, lib, fetchzip, autoPatchelfHook, patchelf, makeWrapper, nodejs }:
let
  sources = {
    "x86_64-linux" = {
      url = "https://cli.moonbitlang.com/binaries/latest/moonbit-linux-x86_64.tar.gz";
      sha256 = "sha256-mkyslthuoqDLdvbmnYHpe2OeIfsS2/I+InwXbWZUOS0=";
    };
    "aarch64-darwin" = {
      url = "https://cli.moonbitlang.com/binaries/latest/moonbit-darwin-aarch64.tar.gz";
      sha256 = "sha256-k5BHB8vy8/IzahQbyjI0uHMsykHyG2RJHHfwOI02TmM=";
    };
  };
  source = sources.${stdenv.hostPlatform.system} or (throw "moonbit: unsupported system ${stdenv.hostPlatform.system}");
  coreSrc = fetchzip {
    url = "https://cli.moonbitlang.com/cores/core-latest.tar.gz";
    sha256 = "sha256-ceMJRnDjsgaOv0qcbwJemN8snS+ZV/so3ZA5kb7qT1A=";
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
    ../../bin/moon bundle --all
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
