{ stdenv,fetchzip,fetchFromGithub }:
let coreSrc = fetchFromGithub{
  owner = "moonbitlang";
  repo = "core";
};
in
stdenv.mkDerivation  {
  name = "moonbit-dev";
  src = fetchzip{
    url= "https://cli.moonbitlang.com/binaries/latest/moonbit-linux-x86_64-dev.tar.gz";
    sha256="";
  };
  
  buildPhase = ''
    runHook preBuild
    chmod + x ./bin/moon ./bin moonc ./bin/intrernal/tcc
    ./bin/moon bundle --all --source-dir ${coreSrc}
    ./bin/moon bundle --target wasm-gc --source-dir ${coreSrc} --quiet
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
}
