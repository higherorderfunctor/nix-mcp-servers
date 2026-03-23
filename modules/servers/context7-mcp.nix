{lib, ...}: let
  inherit (lib) mkOption types optional optionalAttrs optionals;
in {
  meta = {
    modes = ["stdio" "http"];
    scope = "remote";
    defaultPort = 19750;
    tools = ["query-docs" "resolve-library-id"];
  };

  settingsOptions = {
    apiKey = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Context7 API key. Only used in stdio mode (rejected in HTTP mode).
        Can be obtained at context7.com/dashboard.
      '';
    };

    apiUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Override the base URL for the Context7 API.";
    };
  };

  settingsToEnv = cfg:
    optionalAttrs (cfg.settings.apiUrl != null) {
      CONTEXT7_API_URL = cfg.settings.apiUrl;
    }
    # API key via env only when not using --api-key CLI arg (stdio uses CLI, http uses header)
    // optionalAttrs (cfg.transport == "stdio" && cfg.settings.apiKey != null) {
      CONTEXT7_API_KEY = cfg.settings.apiKey;
    };

  settingsToArgs = cfg:
    optionals (cfg.transport == "http" && cfg.port != null) ["--port" (toString cfg.port)]
    ++ optional (cfg.transport == "stdio" && cfg.settings.apiKey != null) "--api-key=${cfg.settings.apiKey}";
}
