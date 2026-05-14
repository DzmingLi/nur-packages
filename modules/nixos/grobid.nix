{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.grobid;

  # grobidHome must be a WRITABLE absolute path. Some internal code paths
  # (notably pdfalto temp-file creation) resolve `<grobidHome>/tmp` directly
  # and ignore the configured `temp` setting — so even with `temp:` pointed
  # elsewhere, writes to `<grobidHome>/tmp` fail when grobidHome lives in
  # the read-only nix store. ExecStartPre below populates a writable mirror
  # via `cp -rs` (read-only files become symlinks back to the package; only
  # `tmp/` is a real writable directory).
  grobidStateHome = "/var/lib/grobid/grobid-home";

  configFile = pkgs.runCommand "grobid.yaml"
    { nativeBuildInputs = [ pkgs.yq-go ]; }
    ''
      yq '
        .server.applicationConnectors[0].port = ${toString cfg.port}
        | .server.applicationConnectors[0].bindHost = "${cfg.listenAddress}"
        | .server.adminConnectors[0].port = ${toString cfg.adminPort}
        | .server.adminConnectors[0].bindHost = "${cfg.listenAddress}"
        | .grobid.grobidHome = "${grobidStateHome}"
        | .grobid.temp = "${grobidStateHome}/tmp"
        | .grobid.concurrency = ${toString cfg.concurrency}
      ' ${cfg.package}/share/grobid/grobid-home/config/grobid.yaml > $out
    '';

  prepScript = pkgs.writeShellScript "grobid-prep" ''
    set -eu
    src="${cfg.package}/share/grobid/grobid-home"
    dst="${grobidStateHome}"
    # Repopulate when the source package changes (marker file tracks it).
    marker="$dst/.populated-from"
    expected="${cfg.package}"
    if [ ! -e "$marker" ] || [ "$(cat "$marker" 2>/dev/null)" != "$expected" ]; then
      # Wipe any previous mirror. Directories inherited 555 from the nix
      # store via `cp -rs`, so chmod first or rm fails "Permission denied".
      if [ -d "$dst" ]; then
        chmod -R u+w "$dst"
        rm -rf "$dst"
      fi
      mkdir -p "$(dirname "$dst")"
      ${pkgs.coreutils}/bin/cp -rsf "$src" "$dst"
      # cp -rs propagates source dir mode (555). Make every dir writable so
      # subsequent restarts can clean up + grobid can write into tmp.
      chmod -R u+w "$dst"
      # tmp ships as a symlink/dir inside grobid-home; replace with a real
      # writable directory so pdfalto can write its temp PDFs.
      rm -rf "$dst/tmp"
      mkdir -p "$dst/tmp"
      printf %s "$expected" > "$marker"
    fi
  '';
in
{
  options.services.grobid = {
    enable = mkEnableOption "GROBID scholarly-PDF extraction service";

    package = mkOption {
      type = types.package;
      default = pkgs.grobid;
      defaultText = literalExpression "pkgs.grobid";
      description = "The grobid package to use.";
    };

    listenAddress = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address the GROBID HTTP service binds to.";
    };

    port = mkOption {
      type = types.port;
      default = 8070;
      description = "Port for the GROBID HTTP API.";
    };

    adminPort = mkOption {
      type = types.port;
      default = 8071;
      description = "Port for the GROBID admin endpoint (health, metrics).";
    };

    concurrency = mkOption {
      type = types.ints.positive;
      default = 10;
      description = ''
        Maximum concurrent requests served by GROBID.
        Upstream guidance: slightly above the available CPU thread count.
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the configured ports in the firewall.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.grobid = {
      description = "GROBID scholarly-PDF extraction service";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        DynamicUser = true;
        StateDirectory = "grobid";
        WorkingDirectory = "/var/lib/grobid";
        ExecStartPre = "${prepScript}";
        ExecStart = "${cfg.package}/bin/grobid-service server ${configFile}";
        Restart = "on-failure";
        RestartSec = "10s";

        # Hardening
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        NoNewPrivileges = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = false; # JVM JIT writes-then-execs
        SystemCallArchitectures = "native";
      };
    };

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ cfg.port ];
  };
}
