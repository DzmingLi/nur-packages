{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.grobid;

  configFile = pkgs.runCommand "grobid.yaml"
    { nativeBuildInputs = [ pkgs.yq-go ]; }
    ''
      yq '
        .server.applicationConnectors[0].port = ${toString cfg.port}
        | .server.applicationConnectors[0].bindHost = "${cfg.listenAddress}"
        | .server.adminConnectors[0].port = ${toString cfg.adminPort}
        | .server.adminConnectors[0].bindHost = "${cfg.listenAddress}"
        | .grobid.temp = "/var/lib/grobid/tmp"
        | .grobid.concurrency = ${toString cfg.concurrency}
      ' ${cfg.package}/share/grobid/grobid-home/config/grobid.yaml > $out
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
        WorkingDirectory = "${cfg.package}/share/grobid";
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /var/lib/grobid/tmp";
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
