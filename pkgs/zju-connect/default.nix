{
  buildGoModule,
  fetchFromGitHub,
  lib,
  pkg-config,
  stdenv,
}:
buildGoModule (finalAttrs: {
  pname = "zju-connect";
  version = "1.0.0";
  src = fetchFromGitHub {
    owner = "Mythologyli";
    repo = "zju-connect";
    tag = "v${finalAttrs.version}";
    hash = "sha256-JS0C8j5tAYTrOa7ZYxnq9vSqHJk/YZO/qPX5E+cFhVc=";
  };
  vendorHash = "sha256-H+WtDkq8FckXuriEQNh1vhsGIkw1U7RlhQeAbO0jUXQ=";

  buildInputs = [
    stdenv.cc.cc.lib
  ];

  nativeBuildInputs = [
    pkg-config
  ];

  ldflags = [
    "-s"
    "-w"
  ];

  meta = {
    mainProgram = "zju-connect";
    description = "SSL VPN client based on EasierConnect";
    homepage = "https://github.com/Mythologyli/zju-connect";
    license = lib.licenses.agpl3Only;
    platforms = lib.platforms.unix;
  };
})
