{
  buildGoModule,
  fetchFromGitHub,
  lib,
}:
buildGoModule (finalAttrs: {
  pname = "telegram-mcp";
  version = "0.2.0";
  src = fetchFromGitHub {
    owner = "chaindead";
    repo = "telegram-mcp";
    tag = "v${finalAttrs.version}";
    hash = "sha256-fhHW8+IM6xLfdFvpvoOrzpgiSSN/Wgyp0l/kPeT8VEA=";
  };
  vendorHash = "sha256-4pKxV43UHWZWRzZ1hVHK4rYX1vUsZK073+kJNHaWzIU=";

  ldflags = [
    "-s"
    "-w"
  ];

  meta = {
    mainProgram = "telegram-mcp";
    description = "Telegram MCP server for Claude Code";
    homepage = "https://github.com/chaindead/telegram-mcp";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
