{
  buildGoModule,
  fetchFromGitHub,
  lib,
  nix-update-script,
  pkg-config,
  stdenv,
}:
buildGoModule (finalAttrs: {
  pname = "zju-connect";
  version = "1.0.0-unstable-2026-03-25";
  src = fetchFromGitHub {
    owner = "Mythologyli";
    repo = "zju-connect";
    rev = "57ee9b6ef00375f64fb7b166b53f81e1b9ffadf0";
    hash = "sha256-qRAo/PvSmfwhYh9IJ/iHNX8J2ARN8c1V3Vf763vZ7co=";
  };
  vendorHash = "sha256-H+WtDkq8FckXuriEQNh1vhsGIkw1U7RlhQeAbO0jUXQ=";

  patches = [
    # Fix L3Conn.{Read,Write} retry loop:
    #   1. SendConn/RecvConn re-handshake failures (e.g. "unexpected send
    #      handshake reply") used to bail out immediately, exhausting only 1
    #      of the 5 retry attempts and propagating the error to a panic at
    #      stack/gvisor/stack.go:105.
    #   2. After a successful re-handshake the original `for n, err = ...; ...; {}`
    #      loop exited (because err == nil) without actually retrying the
    #      failed Read/Write on the new conn — silently returning n=0, err=nil.
    # Rewrite the loop so re-handshake failures count against the retry
    # budget and a successful re-handshake actually retries the I/O.
    ./l3conn-retry-fix.patch
  ];

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

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--version=branch" ];
  };

  meta = {
    mainProgram = "zju-connect";
    description = "SSL VPN client based on EasierConnect";
    homepage = "https://github.com/Mythologyli/zju-connect";
    license = lib.licenses.agpl3Only;
    platforms = lib.platforms.unix;
  };
})
