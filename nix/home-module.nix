self:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.os-tracker;
in
{
  options.services.os-tracker = {
    enable = lib.mkEnableOption "the os-tracker presence daemon";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.os-tracker;
      defaultText = lib.literalExpression "os-tracker.packages.\${system}.os-tracker";
      description = "The os-tracker package to run.";
    };

    apiUrl = lib.mkOption {
      type = lib.types.str;
      example = "https://os-tracker.example.workers.dev";
      description = "Base URL of the heartbeat API, without a trailing slash.";
    };

    interval = lib.mkOption {
      type = lib.types.ints.positive;
      default = 120;
      description = "Seconds between two heartbeats.";
    };

    tokenFile = lib.mkOption {
      type = lib.types.str;
      example = "/home/alice/.config/os-tracker/token.env";
      description = ''
        Path to a systemd environment file holding the bearer token as
        `OS_TRACKER_TOKEN=<token>`. It is read at service start, so the token
        stays out of the Nix store and out of the configuration repository.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.isLinux;
        message = "services.os-tracker needs systemd; on macOS install it with Homebrew instead.";
      }
    ];

    systemd.user.services.os-tracker = {
      Unit = {
        Description = "OS presence tracker daemon";
        Documentation = "https://github.com/mael-app/os-tracker";
      };

      Service = {
        Type = "simple";
        ExecStart = lib.getExe cfg.package;
        # The daemon reads its whole configuration from the environment when
        # both the URL and the token are set, so no config.toml is needed.
        Environment = [
          "OS_TRACKER_API_URL=${cfg.apiUrl}"
          "OS_TRACKER_INTERVAL=${toString cfg.interval}"
        ];
        EnvironmentFile = cfg.tokenFile;
        Restart = "on-failure";
        RestartSec = 30;
      };

      Install.WantedBy = [ "default.target" ];
    };
  };
}
