{lib, ...}: let
  inherit (lib) mkOption types optionalAttrs;

  boolToString = b:
    if b
    then "true"
    else "false";
in {
  meta = {
    modes = ["stdio" "http"];
    scope = "remote";
    defaultPort = 19752;
    tools = ["nix" "nix_versions"];
  };

  settingsOptions = {
    path = mkOption {
      type = types.str;
      default = "/mcp";
      description = "HTTP endpoint path (must start with /). Only used in HTTP mode.";
    };

    statelessHttp = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = "Enable stateless HTTP mode (disables per-client session state).";
    };
  };

  settingsToEnv = cfg:
    optionalAttrs (cfg.transport == "http") (
      {
        MCP_NIXOS_PORT = toString cfg.port;
      }
      // optionalAttrs (cfg.host != "127.0.0.1") {
        MCP_NIXOS_HOST = cfg.host;
      }
      // optionalAttrs (cfg.settings.path != "/mcp") {
        MCP_NIXOS_PATH = cfg.settings.path;
      }
      // optionalAttrs (cfg.settings.statelessHttp != null) {
        MCP_NIXOS_STATELESS_HTTP = boolToString cfg.settings.statelessHttp;
      }
    );

  settingsToArgs = _cfg: [];
}
