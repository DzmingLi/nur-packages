{ lib
, stdenv
, dockerTools
, autoPatchelfHook
, jq
, javaPackages
, libxml2
, fontconfig
, zlib
, expat
, libpng
}:

let
  version = "0.9.0";

  archConfig = {
    "x86_64-linux" = {
      imageDigest = "sha256:2fc3fc42a91625177205c33a7855a60500a72301d8d4d9c38b69d91e44bea573";
      sha256 = "sha256-bxFQ7wao9BZ3K2JexvCA1E37NFICG22nU2Zbaj5fNKM=";
      arch = "amd64";
      nativeLibDir = "lin-64";
    };
    # arm64: digest is valid but tarball sha256 is not yet verified on this host.
    # First build on aarch64-linux will print the real hash; replace lib.fakeSha256.
    "aarch64-linux" = {
      imageDigest = "sha256:35864239748c6320f5afa5fa8b9e8e241e4162d7424e731c2ca9f5348ba6c15f";
      sha256 = lib.fakeSha256;
      arch = "arm64";
      nativeLibDir = "lin_arm-64";
    };
  };

  archEntry = archConfig.${stdenv.hostPlatform.system}
    or (throw "grobid: unsupported platform ${stdenv.hostPlatform.system}");

  image = dockerTools.pullImage {
    imageName = "grobid/grobid";
    inherit (archEntry) imageDigest sha256 arch;
    finalImageName = "grobid/grobid";
    finalImageTag = "${version}-crf";
    os = "linux";
  };

  jre = javaPackages.compiler.temurin-bin.jre-21;

in
stdenv.mkDerivation {
  pname = "grobid";
  inherit version;

  src = image;

  nativeBuildInputs = [ autoPatchelfHook jq ];
  buildInputs = [
    stdenv.cc.cc.lib
    libxml2
    fontconfig
    zlib
    expat
    libpng
  ];

  unpackPhase = ''
    runHook preUnpack
    mkdir -p image rootfs
    tar -xf $src -C image
    layers=$(jq -r '.[0].Layers[]' image/manifest.json)
    for layer in $layers; do
      tar -xf "image/$layer" -C rootfs
    done
    runHook postUnpack
  '';

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/grobid $out/bin
    cp -r rootfs/opt/grobid/grobid-service $out/share/grobid/
    cp -r rootfs/opt/grobid/grobid-home $out/share/grobid/
    patchShebangs $out/share/grobid/grobid-service/bin

    cat > $out/bin/grobid-service <<EOF
    #!${stdenv.shell}
    export JAVA_HOME=${jre}
    export PATH=${jre}/bin:\''${PATH:-}
    export LD_LIBRARY_PATH=$out/share/grobid/grobid-home/lib/${archEntry.nativeLibDir}\''${LD_LIBRARY_PATH:+:\''${LD_LIBRARY_PATH}}
    : "\''${GROBID_SERVICE_OPTS:=--add-opens java.base/java.lang=ALL-UNNAMED --add-opens java.base/sun.nio.ch=ALL-UNNAMED --add-opens java.base/java.io=ALL-UNNAMED}"
    export GROBID_SERVICE_OPTS
    cd $out/share/grobid
    exec $out/share/grobid/grobid-service/bin/grobid-service "\$@"
    EOF
    chmod +x $out/bin/grobid-service
    runHook postInstall
  '';

  passthru = {
    inherit jre;
    grobidHome = "share/grobid/grobid-home";
  };

  meta = with lib; {
    description = "ML library for extracting and parsing scholarly PDFs (CRF, repackaged from upstream Docker image)";
    homepage = "https://github.com/kermitt2/grobid";
    license = licenses.asl20;
    # aarch64-linux supported in principle but tarball hash not yet verified.
    platforms = [ "x86_64-linux" ];
    mainProgram = "grobid-service";
    sourceProvenance = with sourceTypes; [ binaryNativeCode binaryBytecode ];
  };
}
