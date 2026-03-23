{lib, ...}: let
  inherit (lib) mkOption types optional;
in {
  meta = {
    modes = ["stdio"];
    scope = "remote";
    defaultPort = null;
    tools = ["fetch"];
  };

  settingsOptions = {
    userAgent = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Custom User-Agent string for HTTP requests.";
    };

    proxyUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Proxy URL for outbound HTTP requests.";
    };

    ignoreRobotsTxt = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to ignore robots.txt restrictions.";
    };
  };

  settingsToEnv = _cfg: {};

  settingsToArgs = cfg:
    optional (cfg.settings.userAgent != null) "--user-agent=${cfg.settings.userAgent}"
    ++ optional (cfg.settings.proxyUrl != null) "--proxy-url=${cfg.settings.proxyUrl}"
    ++ optional cfg.settings.ignoreRobotsTxt "--ignore-robots-txt";
}
