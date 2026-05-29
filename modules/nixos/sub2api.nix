{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.sub2api;

  format = pkgs.formats.yaml { };

  runtimeDir = "/run/sub2api";
  stateDir = "/var/lib/sub2api";

  usePostgres = cfg.database.createLocally;
  useRedis = cfg.redis.createLocally;

  # JWT secret and TOTP key are always sourced at runtime: either from an
  # admin-supplied file, or from a stable key auto-generated into the state
  # dir on first boot (so existing TOTP enrollments survive restarts).
  dbPassViaEnv = !usePostgres && cfg.database.passwordFile != null;
  adminViaEnv = cfg.adminPasswordFile != null;

  # Base config assembled from typed options. Secrets are NOT placed here —
  # they are injected at runtime with `yq` (strenv) so any value, including
  # YAML-special characters, is escaped/quoted correctly. User `settings` are
  # deep-merged on top and win on conflict.
  baseSettings = {
    server = {
      host = cfg.host;
      port = cfg.port;
      mode = "release";
    };

    database = {
      host = if usePostgres then "/run/postgresql" else cfg.database.host;
      port = cfg.database.port;
      user = cfg.database.user;
      dbname = cfg.database.name;
      sslmode = if usePostgres then "disable" else cfg.database.sslmode;
    }
    // optionalAttrs usePostgres { password = ""; }
    // optionalAttrs (!usePostgres && cfg.database.password != null) {
      password = cfg.database.password;
    };

    redis = {
      host = if useRedis then "127.0.0.1" else cfg.redis.host;
      port = cfg.redis.port;
      db = cfg.redis.database;
    };

    # Keep persistent caches/media under the state dir (DATA_DIR points at the
    # ephemeral runtime dir, which only holds the rendered config).
    pricing.data_dir = "${stateDir}/data";
    sora.storage.local_path = "${stateDir}/sora";

    # Logs go to journald via stdout; no on-disk log files.
    log.output = {
      to_stdout = true;
      to_file = false;
    };
  }
  // optionalAttrs (cfg.adminEmail != null) {
    default.admin_email = cfg.adminEmail;
  };

  settings = recursiveUpdate baseSettings cfg.settings;

  configTemplate = format.generate "sub2api-config.yaml" settings;

  # yq assignment fragments for the runtime secret injection.
  yqAssignments = [
    ".jwt.secret = strenv(SUB2API_JWT_SECRET)"
    ".totp.encryption_key = strenv(SUB2API_TOTP_KEY)"
  ]
  ++ optional dbPassViaEnv ".database.password = strenv(SUB2API_DB_PASSWORD)"
  ++ optional adminViaEnv ".default.admin_password = strenv(SUB2API_ADMIN_PASSWORD)";

  # Render the runtime config: copy the store template, resolve secrets, then
  # inject them with yq. Runs as root (ExecStartPre=+) so it can read
  # root-only secret files (e.g. agenix) and write the runtime dir, then locks
  # the result down to the service user.
  preStart = pkgs.writeShellScript "sub2api-pre-start" ''
    set -euo pipefail
    umask 077

    secrets_dir="${stateDir}/secrets"
    install -d -m 0700 "$secrets_dir"

    gen_secret() {
      if [ ! -s "$1" ]; then
        ${pkgs.openssl}/bin/openssl rand -hex 32 > "$1"
        chmod 0600 "$1"
      fi
    }

    ${if cfg.jwtSecretFile != null then ''
      SUB2API_JWT_SECRET="$(cat ${escapeShellArg (toString cfg.jwtSecretFile)})"
    '' else ''
      gen_secret "$secrets_dir/jwt.key"
      SUB2API_JWT_SECRET="$(cat "$secrets_dir/jwt.key")"
    ''}
    export SUB2API_JWT_SECRET

    ${if cfg.totpEncryptionKeyFile != null then ''
      SUB2API_TOTP_KEY="$(cat ${escapeShellArg (toString cfg.totpEncryptionKeyFile)})"
    '' else ''
      gen_secret "$secrets_dir/totp.key"
      SUB2API_TOTP_KEY="$(cat "$secrets_dir/totp.key")"
    ''}
    export SUB2API_TOTP_KEY

    ${optionalString dbPassViaEnv ''
      SUB2API_DB_PASSWORD="$(cat ${escapeShellArg (toString cfg.database.passwordFile)})"
      export SUB2API_DB_PASSWORD
    ''}

    ${optionalString adminViaEnv ''
      SUB2API_ADMIN_PASSWORD="$(cat ${escapeShellArg (toString cfg.adminPasswordFile)})"
      export SUB2API_ADMIN_PASSWORD
    ''}

    install -m 0600 ${configTemplate} "${runtimeDir}/config.yaml"
    ${pkgs.yq-go}/bin/yq -i ${escapeShellArg (concatStringsSep " | " yqAssignments)} \
      "${runtimeDir}/config.yaml"
    chown ${cfg.user}:${cfg.group} "${runtimeDir}/config.yaml"
    chmod 0400 "${runtimeDir}/config.yaml"
  '';

in
{
  options.services.sub2api = {
    enable = mkEnableOption "Sub2API unified AI API gateway";

    package = mkOption {
      type = types.package;
      default = pkgs.sub2api;
      defaultText = literalExpression "pkgs.sub2api";
      description = "The sub2api package to use.";
    };

    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address the server binds to. Use 0.0.0.0 to listen on all interfaces.";
    };

    port = mkOption {
      type = types.port;
      default = 8080;
      description = "Port the server listens on.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open {option}`services.sub2api.port` in the firewall.";
    };

    user = mkOption {
      type = types.str;
      default = "sub2api";
      description = "User account under which sub2api runs.";
    };

    group = mkOption {
      type = types.str;
      default = "sub2api";
      description = "Group under which sub2api runs.";
    };

    adminEmail = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "admin@example.com";
      description = "Initial admin account email, created on first run.";
    };

    adminPasswordFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Path to a file containing the initial admin password (created on first
        run). Recommended over putting the password in {option}`settings`.
        Compatible with agenix/sops secret paths.
      '';
    };

    jwtSecretFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Path to a file containing the JWT signing secret. If unset, a stable
        random secret is generated into ${stateDir}/secrets on first boot.
      '';
    };

    totpEncryptionKeyFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Path to a file containing the TOTP (2FA) encryption key. If unset, a
        stable random key is generated into ${stateDir}/secrets on first boot.
        Do not lose this key: changing it invalidates all existing 2FA setups.
      '';
    };

    database = {
      createLocally = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether to provision a local PostgreSQL database and connect to it
          over the local unix socket using peer authentication (no password).
          Set to false to connect to an external database.
        '';
      };

      host = mkOption {
        type = types.str;
        default = "localhost";
        description = "PostgreSQL host (ignored when {option}`createLocally` is true).";
      };

      port = mkOption {
        type = types.port;
        default = 5432;
        description = "PostgreSQL port.";
      };

      name = mkOption {
        type = types.str;
        default = "sub2api";
        description = "PostgreSQL database name.";
      };

      user = mkOption {
        type = types.str;
        default = "sub2api";
        description = "PostgreSQL user name.";
      };

      sslmode = mkOption {
        type = types.enum [ "disable" "prefer" "require" "verify-ca" "verify-full" ];
        default = "prefer";
        description = "PostgreSQL SSL mode (ignored when {option}`createLocally` is true).";
      };

      password = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          PostgreSQL password for an external database. Prefer
          {option}`passwordFile`; this value is world-readable in the Nix store.
        '';
      };

      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to a file containing the PostgreSQL password for an external database.";
      };
    };

    redis = {
      createLocally = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether to provision a local Redis instance bound to 127.0.0.1.
          Set to false to connect to an external Redis.
        '';
      };

      host = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Redis host (ignored when {option}`createLocally` is true).";
      };

      port = mkOption {
        type = types.port;
        default = 6379;
        description = "Redis port.";
      };

      database = mkOption {
        type = types.int;
        default = 0;
        description = "Redis database number (0-15).";
      };
    };

    settings = mkOption {
      type = format.type;
      default = { };
      example = literalExpression ''
        {
          server.frontend_url = "https://sub2api.example.com";
          cors.allowed_origins = [ "https://sub2api.example.com" ];
          run_mode = "standard";
        }
      '';
      description = ''
        Free-form settings merged into and overriding the generated
        config.yaml. See the upstream config.example.yaml for all keys:
        <https://github.com/Wei-Shaw/sub2api/blob/main/deploy/config.example.yaml>.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = !(cfg.database.createLocally && cfg.database.password != null);
        message = "services.sub2api.database.password is ignored when createLocally is true (peer auth is used); unset it.";
      }
      {
        assertion = cfg.database.createLocally
          || cfg.database.passwordFile != null
          || cfg.database.password != null;
        message = "services.sub2api: set database.passwordFile (or .password) when database.createLocally is false.";
      }
    ];

    services.postgresql = mkIf usePostgres {
      enable = true;
      ensureDatabases = [ cfg.database.name ];
      ensureUsers = [
        {
          name = cfg.database.user;
          ensureDBOwnership = true;
        }
      ];
    };

    services.redis.servers.sub2api = mkIf useRedis {
      enable = true;
      bind = "127.0.0.1";
      port = cfg.redis.port;
    };

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ cfg.port ];

    users.users = mkIf (cfg.user == "sub2api") {
      sub2api = {
        isSystemUser = true;
        group = cfg.group;
        home = stateDir;
      };
    };

    users.groups = mkIf (cfg.group == "sub2api") {
      sub2api = { };
    };

    systemd.services.sub2api = {
      description = "Sub2API - AI API Gateway Platform";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ]
        ++ optional usePostgres "postgresql.service"
        ++ optional useRedis "redis-sub2api.service";
      wants = [ "network-online.target" ]
        ++ optional usePostgres "postgresql.service"
        ++ optional useRedis "redis-sub2api.service";

      environment = {
        DATA_DIR = runtimeDir;
        GIN_MODE = "release";
      };

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStartPre = "+${preStart}";
        ExecStart = "${getExe cfg.package}";
        WorkingDirectory = stateDir;
        StateDirectory = "sub2api";
        StateDirectoryMode = "0750";
        RuntimeDirectory = "sub2api";
        RuntimeDirectoryMode = "0700";
        Restart = "on-failure";
        RestartSec = 5;

        # Hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
        RestrictNamespaces = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        SystemCallFilter = [ "@system-service" ];
        SystemCallErrorNumber = "EPERM";
      };
    };
  };
}
