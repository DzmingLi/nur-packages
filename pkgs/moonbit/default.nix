{ stdenv, lib, fetchzip, autoPatchelfHook, patchelf, makeWrapper, nodejs }:
let
  sources = {
    "x86_64-linux" = {
      url = "https://cli.moonbitlang.com/binaries/latest/moonbit-linux-x86_64.tar.gz";
      sha256 = "sha256-4FFtqCFA6g/CvkMK44ENvkE36AoT8eW6ZKUK9E/v8Tk=";
    };
    "aarch64-darwin" = {
      url = "https://cli.moonbitlang.com/binaries/latest/moonbit-darwin-aarch64.tar.gz";
      sha256 = "sha256-VYej2iR5NDZRtbf7XsuvOT+DYQJYdyZbqck7cR3roMg=";
    };
  };
  source = sources.${stdenv.hostPlatform.system} or (throw "moonbit: unsupported system ${stdenv.hostPlatform.system}");
  coreSrc = fetchzip {
    url = "https://cli.moonbitlang.com/cores/core-latest.tar.gz";
    sha256 = "sha256-T9Hs7AxrZ+Ywb0lLrpgQEOi08EP530Y5h3rzNtKq4VE=";
  };
  # moon uses a single MOON_HOME for both the (read-only) toolchain and its
  # (writable) user state — credentials.json, the registry index, .mooncakes.
  # Pinning it at the read-only store path breaks `moon login` / `moon publish`.
  # Instead default MOON_HOME to a writable per-user dir (honouring an explicit
  # override) and symlink the toolchain assets in from the store. `ln -sfn`
  # refreshes our own links on a version bump; the symlink/absent guard keeps
  # us from clobbering a real ~/.moon left by an official installer.
  moonHomeSetup = ''
    export MOON_HOME="''${MOON_HOME:-$HOME/.moon}"
    mkdir -p "$MOON_HOME"
    for d in bin lib include; do
      if [ -L "$MOON_HOME/$d" ] || [ ! -e "$MOON_HOME/$d" ]; then
        ln -sfn "${placeholder "out"}/$d" "$MOON_HOME/$d"
      fi
    done
  '';
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
    wrapProgram $out/bin/moon --run ${lib.escapeShellArg moonHomeSetup}
    wrapProgram $out/bin/moonbit-lsp \
      --run ${lib.escapeShellArg moonHomeSetup} \
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
