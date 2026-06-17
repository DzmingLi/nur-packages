{
  lib,
  stdenv,
  buildGoModule,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_9,
  nodejs_24,
  nix-update-script,
}:

let
  version = "0.1.137";

  # Pin pnpm 9 (lockfileVersion 9.0; upstream Dockerfile pins pnpm@9) on the
  # top-level fetcher/hook so we keep the supported version without the
  # deprecated `pnpm_9.fetchDeps` / `pnpm_9.configHook` attribute paths.
  fetchPnpmDeps' = fetchPnpmDeps.override { pnpm = pnpm_9; };
  pnpmConfigHook' = pnpmConfigHook.override { pnpm = pnpm_9; };

  src = fetchFromGitHub {
    owner = "Wei-Shaw";
    repo = "sub2api";
    tag = "v${version}";
    hash = "sha256-EtrbY7LXxqT7bLjVcJ/TCQR6fEhxe403XINiXIm4ntI=";
  };

  # go.mod pins an exact patch release (e.g. `go 1.26.3`); nixpkgs may only
  # ship a lower 1.26.x. Strip the patch component to the two-component form
  # so any matching-minor toolchain satisfies it. Regex-based (not a literal
  # version) so upstream `go` bumps need no edit here — keeps auto-update
  # hands-off until the nixpkgs go *minor* itself lags, which unstable fixes
  # within days.
  relaxGoVersion = ''
    sed -ri 's/^(go [0-9]+\.[0-9]+)\.[0-9]+$/\1/' backend/go.mod
  '';

  # Stage 1: build the Vue/Vite frontend. Vite emits into
  # ../backend/internal/web/dist (relative to frontend/), which is exactly the
  # path the Go backend embeds via `//go:embed all:dist` under `-tags embed`.
  frontend = stdenv.mkDerivation (finalAttrs: {
    pname = "sub2api-frontend";
    inherit version src;
    sourceRoot = "${finalAttrs.src.name}/frontend";

    pnpmDeps = fetchPnpmDeps' {
      inherit (finalAttrs) pname version src sourceRoot;
      fetcherVersion = 3;
      hash = "sha256-gw2nPBfJUFb/RpIdQroQybCIrFOziMDdzmDTqizQSlQ=";
    };

    nativeBuildInputs = [
      nodejs_24
      pnpm_9
      pnpmConfigHook'
    ];

    buildPhase = ''
      runHook preBuild
      # vite writes to ../backend/internal/web/dist, but the unpacked source
      # tree outside sourceRoot is read-only — make the target writable first.
      chmod -R u+w ../backend/internal/web
      pnpm run build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      cp -r ../backend/internal/web/dist "$out"
      runHook postInstall
    '';
  });
in
buildGoModule {
  pname = "sub2api";
  inherit version src;

  modRoot = "backend";
  vendorHash = "sha256-rfv0MEUx2IXf3GsDVVZhEIyvKAW0L68tyzbrP5f4iqk=";

  # Applied to both the main build and the module-vendor build (which also
  # runs `go mod download` and would otherwise trip the toolchain check).
  postPatch = relaxGoVersion;
  overrideModAttrs = _: { postPatch = relaxGoVersion; };

  # Drop the prebuilt frontend into the embed path before the `-tags embed`
  # Go build runs (preBuild executes inside modRoot = backend/).
  preBuild = ''
    cp -r ${frontend} internal/web/dist
    chmod -R u+w internal/web/dist
  '';

  tags = [ "embed" ];
  subPackages = [ "cmd/server" ];

  env.CGO_ENABLED = 0;

  ldflags = [
    "-s"
    "-w"
    "-X main.Version=${version}"
    "-X main.Commit=nixpkgs"
    "-X main.BuildType=release"
  ];

  # Upstream names the binary `server`; expose it under the project name.
  postInstall = ''
    mv "$out/bin/server" "$out/bin/sub2api"
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Unified AI API gateway relaying Claude/OpenAI/Gemini subscriptions with billing and sharing";
    homepage = "https://github.com/Wei-Shaw/sub2api";
    license = lib.licenses.lgpl3Only;
    mainProgram = "sub2api";
    platforms = lib.platforms.linux;
  };
}
