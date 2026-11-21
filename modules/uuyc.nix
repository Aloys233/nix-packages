{ self ? null }:
{ config, lib, pkgs, ... }:

let
  cfg = config.services.uuyc;
  defaultPackage =
    if pkgs ? uuyc then pkgs.uuyc
    else if self != null && self ? packages && self.packages ? ${pkgs.stdenv.hostPlatform.system} && self.packages.${pkgs.stdenv.hostPlatform.system} ? uuyc
    then self.packages.${pkgs.stdenv.hostPlatform.system}.uuyc
    else throw "services.uuyc.package must be set when uuyc is not present in pkgs";
in
{
  options.services.uuyc = {
    enable = lib.mkEnableOption "NetEase UU Remote (网易UU远程) host service and desktop client";

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPackage;
      defaultText = lib.literalExpression "pkgs.uuyc";
      description = "The uuyc package to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
    ];

    systemd.sockets.uuyc = {
      description = "uuyc Service Control Socket";
      wantedBy = [ "sockets.target" ];
      socketConfig = {
        ListenStream = "/run/uuyc-control.sock";
        SocketMode = "0666";
        RemoveOnStop = true;
      };
    };

    systemd.services.uuyc = {
      description = "uuyc Server Supervisor";
      requires = [ "uuyc.socket" ];
      after = [ "uuyc.socket" "systemd-user-sessions.service" ];
      wantedBy = [ "multi-user.target" ];

      path = with pkgs; [
        systemd
        glib
        dbus
        bash
        coreutils
        gnugrep
      ];

      environment = {
        NRD_LOG_ROOT = "/var/log/uuyc";
        LD_LIBRARY_PATH = "/run/opengl-driver/lib";
        PIPEWIRE_MODULE_DIR = "${cfg.package}/opt/uuyc/lib/pipewire-0.3";
        PIPEWIRE_CONFIG_PREFIX = "${cfg.package}/opt/uuyc/share/pipewire";
        SPA_PLUGIN_DIR = "${cfg.package}/opt/uuyc/lib/spa-0.2";
        TERMINFO_DIRS = "${cfg.package}/opt/uuyc/share/terminfo";
        SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        SSL_CERT_DIR = "/etc/ssl/certs";
        CURL_CA_BUNDLE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      };

      unitConfig = {
        StartLimitIntervalSec = 60;
        StartLimitBurst = 5;
      };

      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/opt/uuyc/bin/uuyc_service";
        Sockets = [ "uuyc.socket" ];
        RuntimeDirectory = "uuyc";
        RuntimeDirectoryMode = "0700";
        RuntimeDirectoryPreserve = "restart";
        Restart = "on-failure";
        RestartSec = 2;
        TimeoutStopSec = 15;
        KillMode = "mixed";
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };

    # 创建上游 postinst 所需的持久化状态目录、日志目录以及硬编码路径兼容软链接
    systemd.tmpfiles.rules = [
      "d /var/lib/Netease 0755 root root -"
      "d /var/lib/Netease/uuyc 0755 root root -"
      "C /var/lib/Netease/uuyc/install_config.ini 0644 root root - ${cfg.package}/lib/uuyc/install_config.ini"
      "d /var/lib/Netease/uuyc/cache 0700 root root -"
      "d /var/lib/Netease/uuyc/ftp_metadata 0700 root root -"

      "d /var/log/uuyc 0755 root root -"
      "d /var/log/uuyc/client 1777 root root -"
      "d /var/log/uuyc/client/log 1777 root root -"
      "d /var/log/uuyc/server 0755 root root -"
      "d /var/log/uuyc/server/log 0755 root root -"
      "d /var/log/uuyc/healthd 0755 root root -"
      "d /var/log/uuyc/healthd/log 0755 root root -"
      "d /var/log/uuyc/upgrade 1777 root root -"
      "d /var/log/uuyc/upgrade/log 1777 root root -"
      "d /var/log/uuyc/service 0755 root root -"
      "d /var/log/uuyc/service/log 0755 root root -"
      "d /var/log/uuyc/launcher 1777 root root -"
      "d /var/log/uuyc/launcher/log 1777 root root -"
      "d /var/log/uuyc/uuyc-cli 1777 root root -"
      "d /var/log/uuyc/uuyc-cli/log 1777 root root -"
      "d /var/log/uuyc/webview_host 1777 root root -"

      "d /opt/uuyc 0755 root root -"
      "d /opt/uuyc/libexec 0755 root root -"
      "d /opt/uuyc/share 0755 root root -"
      "L+ /opt/uuyc/libexec/tmux - - - - ${cfg.package}/opt/uuyc/libexec/tmux"
      "L+ /opt/uuyc/libexec/fusermount3 - - - - /run/wrappers/bin/fusermount3"
      "L+ /opt/uuyc/share/terminfo - - - - ${cfg.package}/opt/uuyc/share/terminfo"
      "L+ /opt/uuyc/log - - - - /var/log/uuyc"

      "d /usr/lib/uuyc 0755 root root -"
      "L+ /usr/lib/uuyc/uuyc-gui-session-start - - - - ${cfg.package}/lib/uuyc/uuyc-gui-session-start"
      "L /usr/bin/systemd-run - - - - /run/current-system/sw/bin/systemd-run"
      "L /usr/bin/gdbus - - - - ${pkgs.glib}/bin/gdbus"
      "L /usr/bin/gsettings - - - - ${pkgs.glib}/bin/gsettings"
    ];
  };
}
