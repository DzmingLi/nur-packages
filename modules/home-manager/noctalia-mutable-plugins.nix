{ config, lib, pkgs, ... }:

let
  cfg = config.programs.noctalia-shell;
  jsonFormat = pkgs.formats.json { };

  # Only activate when noctalia-shell is enabled and plugins is non-empty
  hasPlugins = cfg.enable && cfg.plugins != { };

  pluginsFile = jsonFormat.generate "noctalia-plugins.json" cfg.plugins;
in
{
  config = lib.mkIf hasPlugins {
    # Disable the upstream read-only symlink for plugins.json
    xdg.configFile."noctalia/plugins.json" = lib.mkForce {};

    # Write plugins.json as a mutable file so noctalia can update it at runtime
    home.activation.noctaliaMutablePlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      target="$HOME/.config/noctalia/plugins.json"
      mkdir -p "$(dirname "$target")"
      if [ -L "$target" ]; then
        rm "$target"
      fi
      cp --no-preserve=mode "${pluginsFile}" "$target"
    '';
  };
}
