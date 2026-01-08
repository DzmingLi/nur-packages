{
  buildGoModule,
  fetchFromGitHub,
  lib,
}:
buildGoModule (finalAttrs: {
  pname = "clash-speedtest";
  version = "3.0.1";

  src = fetchFromGitHub {
    owner = "starudream";
    repo = "clash-speedtest";
    rev = "v${finalAttrs.version}";
    hash = "sha256-dcZE+zM4Agl2BpupmYl+1OeBnJ6Kg6LfJ8Gzfu5mj+k=";
  };

  vendorHash = "sha256-OlIq6um+WqUXI/VsMN9O8o3NFr5CRmG2VDpsgOu2Rqc=";
  subPackages = [ "./cmd" ];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/starudream/go-lib/core/v2/config/version.gitVersion=v${finalAttrs.version}"
  ];

  env = {
    CGO_ENABLED = "0";
  };

  postInstall = ''
    mv $out/bin/cmd $out/bin/clash-speedtest
  '';

  meta = {
    description = "Clash node speed test tool";
    homepage = "https://github.com/starudream/clash-speedtest";
    license = lib.licenses.asl20;
    mainProgram = "clash-speedtest";
  };
})
