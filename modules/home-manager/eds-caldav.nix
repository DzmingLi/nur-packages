{ config, lib, pkgs, ... }:

let
  cfg = config.accounts.calendar;

  edsAccounts = lib.filterAttrs
    (_: acc: acc.eds.enable && acc.remote != null && acc.remote.type == "caldav")
    cfg.accounts;

  mkEdsSource = name: account: let
    remote = account.remote;
    displayName = if account.eds.displayName != null then account.eds.displayName else name;
  in lib.concatStringsSep "\n" (lib.filter (s: s != "") [
    "[Data Source]"
    "DisplayName=${displayName}"
    "Enabled=true"
    "Parent="
    ""
    "[Calendar]"
    "BackendName=caldav"
    "Color=${account.eds.color}"
    ""
    "[Authentication]"
    (lib.optionalString (remote.userName != null) "User=${remote.userName}")
    "Method=plain/password"
    "ProxyUid=system-proxy"
    ""
    "[Security]"
    "Method=tls"
    ""
    "[Offline]"
    "StaySynchronized=true"
    ""
    "[WebDAV]"
    "AvoidIfmatch=false"
    "CalendarAutoSchedule=false"
    "SoupUri=${remote.url}"
    (lib.optionalString account.eds.trustSelfSignedCert "SslTrust=${remote.url}")
  ]);

  # Generate the source file and optionally store password in libsecret
  mkActivationScript = name: account: let
    sourceContent = mkEdsSource name account;
    sourceFile = pkgs.writeText "eds-caldav-${name}.source" sourceContent;
    eds = account.eds;
  in ''
    _eds_dir="${config.xdg.dataHome}/evolution/sources"
    $DRY_RUN_CMD mkdir -p "$_eds_dir"
    $DRY_RUN_CMD cp --no-preserve=mode "${sourceFile}" "$_eds_dir/eds-caldav-${name}.source"
  '' + lib.optionalString (eds.passwordFile != null) ''
    if [ -f "${eds.passwordFile}" ]; then
      _password=$(cat "${eds.passwordFile}" | tr -d '\n')
      ${pkgs.libsecret}/bin/secret-tool store --label="eds-caldav-${name}" \
        e-source-uid "eds-caldav-${name}" <<< "$_password"
    fi
  '';

in
{
  options.accounts.calendar.accounts = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options.eds = {
        enable = lib.mkEnableOption "Evolution Data Server CalDAV source generation";

        displayName = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Display name for the calendar in EDS.
            Defaults to the account name if not set.
          '';
        };

        color = lib.mkOption {
          type = lib.types.str;
          default = "#3584e4";
          example = "#e01b24";
          description = "Calendar color in hex format.";
        };

        passwordFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = lib.literalExpression ''"''${config.age.secrets.caldav-password.path}"'';
          description = ''
            Path to a file containing the CalDAV password.
            The password will be stored in libsecret for EDS to use.

            For agenix:
              passwordFile = config.age.secrets.caldav-password.path;

            For sops-nix:
              passwordFile = config.sops.secrets.caldav-password.path;
          '';
        };

        trustSelfSignedCert = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to trust self-signed SSL certificates.";
        };
      };
    });
  };

  config = lib.mkIf (edsAccounts != { }) {
    home.activation.eds-caldav-sources =
      lib.hm.dag.entryAfter [ "writeBoundary" ] (
        lib.concatStringsSep "\n" (lib.mapAttrsToList mkActivationScript edsAccounts)
      );
  };
}
