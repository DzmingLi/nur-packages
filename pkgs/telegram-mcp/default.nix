{
  lib,
  python3Packages,
  fetchFromGitHub,
}:
python3Packages.buildPythonApplication {
  pname = "telegram-mcp";
  version = "2.0.36";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "chigwell";
    repo = "telegram-mcp";
    tag = "v2.0.36";
    hash = "sha256-BG8w8gIllQ7XMfEzdMQalGHB/KetjeZ6e7zmwgsq9qg=";
  };

  build-system = [ python3Packages.setuptools ];

  # "dotenv" is a stub package redundant with python-dotenv; relax nest-asyncio version bound
  pythonRemoveDeps = [ "dotenv" ];
  pythonRelaxDeps = [ "nest-asyncio" ];

  dependencies = with python3Packages; [
    httpx
    mcp
    nest-asyncio
    python-dotenv
    python-json-logger
    qrcode
    telethon
  ];

  meta = {
    mainProgram = "telegram-mcp";
    description = "Telegram MCP server for Claude Code (chigwell)";
    homepage = "https://github.com/chigwell/telegram-mcp";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
