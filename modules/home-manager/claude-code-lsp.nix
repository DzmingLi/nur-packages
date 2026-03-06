{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.claude-code;
  jsonFormat = pkgs.formats.json { };
  hasLspServers = cfg.lspServers != { };

  lspPluginDir = pkgs.runCommandLocal "claude-code-lsp-plugin" { } ''
    mkdir -p $out/.claude-plugin
    ln -s ${jsonFormat.generate "plugin.json" { name = "nix-lsp-servers"; }} $out/.claude-plugin/plugin.json
    ln -s ${jsonFormat.generate "lsp.json" cfg.lspServers} $out/.lsp.json
  '';
in
{
  options.programs.claude-code.lspServers = lib.mkOption {
    type = lib.types.attrsOf jsonFormat.type;
    default = { };
    description = ''
      LSP (Language Server Protocol) server configurations for Claude Code.

      Claude Code discovers LSP servers through plugins, not by scanning
      {env}`PATH`. This option generates a plugin with the given LSP server
      configurations and passes it via {option}`--plugin-dir`.

      Note: This wraps the default {option}`programs.claude-code.package`.
      If you override {option}`programs.claude-code.package`, set it to a
      lower priority (e.g. {command}`lib.mkDefault`) so the LSP wrapping
      can take effect on top of it.
    '';
    example = lib.literalExpression ''
      {
        nixd = {
          command = "''${pkgs.nixd}/bin/nixd";
          extensionToLanguage.".nix" = "nix";
        };
        pyright = {
          command = "''${pkgs.pyright}/bin/pyright-langserver";
          args = [ "--stdio" ];
          extensionToLanguage = {
            ".py" = "python";
            ".pyi" = "python";
          };
        };
      }
    '';
  };

  config = lib.mkIf (cfg.enable && hasLspServers) {
    assertions = [
      {
        assertion = cfg.package != null;
        message = "`programs.claude-code.package` cannot be null when `lspServers` is configured";
      }
    ];

    programs.claude-code.package = lib.mkOverride 900 (
      pkgs.symlinkJoin {
        name = "claude-code-with-lsp";
        paths = [ pkgs.claude-code ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/claude \
            --append-flags "--plugin-dir ${lspPluginDir}"
        '';
        inherit (pkgs.claude-code) meta;
      }
    );
  };
}
