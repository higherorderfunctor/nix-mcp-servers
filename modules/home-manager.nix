{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    concatStringsSep
    escapeShellArg
    filterAttrs
    getExe
    map
    mapAttrs
    mapAttrs'
    mapAttrsToList
    mkEnableOption
    mkOption
    nameValuePair
    optionalAttrs
    optionals
    types
    ;

  mcpLib = import ../lib {inherit lib;};
  inherit (mcpLib) isExternal;

  cfg = config.services.mcp-servers;

  # ── Import per-server definitions ──────────────────────────────────
  serverFiles = mapAttrs (_: path:
    import path {
      inherit lib;
      mcpLib = import ../lib {inherit lib;};
    }) {
    context7-mcp = ./servers/context7-mcp.nix;
    effect-mcp = ./servers/effect-mcp.nix;
    fetch-mcp = ./servers/fetch-mcp.nix;
    nixos-mcp = ./servers/nixos-mcp.nix;
  };

  # ── Per-server submodule ───────────────────────────────────────────
  mkServerModule = name: serverDef: _: {
    options =
      {
        enable = mkEnableOption "the ${name} MCP server";

        settings = mkOption {
          type = types.submodule {options = serverDef.settingsOptions;};
          default = {};
          description = "Server-specific configuration for ${name}.";
        };

        env = mkOption {
          type = types.attrsOf types.str;
          default = {};
          description = "Extra environment variables (escape hatch for options not yet in settings). Values end up in the Nix store — use credentials for secrets.";
        };

        args = mkOption {
          type = types.listOf types.str;
          default = [];
          description = "Extra CLI arguments (escape hatch for options not yet in settings).";
        };

        scope = mkOption {
          type = types.enum ["local" "remote"];
          default = serverDef.meta.scope;
          readOnly = true;
          internal = true;
          description = "Whether the server is local (filesystem-bound) or remote.";
        };
      }
      // optionalAttrs (!(isExternal serverDef)) {
        package = mkOption {
          type = types.package;
          default = pkgs.${name};
          defaultText = lib.literalExpression "pkgs.${name}";
          description = "The ${name} package to use.";
        };

        service = {
          port = mkOption {
            type = types.port;
            default = serverDef.meta.defaultPort;
            description = "Port to bind for the HTTP service.";
          };

          host = mkOption {
            type = types.str;
            default = "127.0.0.1";
            description = "Host/address to bind for the HTTP service.";
          };
        };
      };
  };

  # ── Credentials helpers ──────────────────────────────────────────────
  credentialVarsFor = name: serverFiles.${name}.meta.credentialVars or {};

  # ── Derived sets ───────────────────────────────────────────────────
  enabledServers = filterAttrs (_: srv: srv.enable) cfg.servers;

  serviceServers =
    filterAttrs
    (name: _: !(isExternal serverFiles.${name}))
    enabledServers;

  # ── Delegate entry building to lib ─────────────────────────────────
  mkHttpEntry = name: srv: let
    serverDef = serverFiles.${name};
    baseEntry = mcpLib.mkHttpEntry ({
        inherit name;
        settings = srv.settings;
      }
      // optionalAttrs (!(isExternal serverDef)) {
        inherit (srv.service) port host;
      });
    credVars = credentialVarsFor name;
    evaluatedSettings = mcpLib.evalSettings name srv.settings;
    hasCreds = mcpLib.hasCredentials credVars evaluatedSettings;
    usesHeaderAuth = (serverDef.meta.httpAuth or null) == "header";
    # Generate a headersHelper script for servers with client-side header auth
    headersHelper = mcpLib.mkHeadersHelper pkgs name credVars evaluatedSettings;
  in
    baseEntry
    // optionalAttrs (usesHeaderAuth && hasCreds) {
      inherit headersHelper;
    };

  # ── Effective env/args for systemd services ────────────────────────
  effectiveEnv = name: srv: mode: let
    evaluatedSettings = mcpLib.evalSettings name srv.settings;
    cfgShim = mcpLib.mkCfgShim {
      inherit evaluatedSettings;
      inherit (srv.service) port host;
    };
  in
    mcpLib.effectiveEnv name cfgShim mode srv.env;

  effectiveArgs = name: srv: mode: let
    evaluatedSettings = mcpLib.evalSettings name srv.settings;
    cfgShim = mcpLib.mkCfgShim {
      inherit evaluatedSettings;
      inherit (srv.service) port host;
    };
  in
    mcpLib.effectiveArgs name cfgShim mode srv.args;
in {
  # ── Options ────────────────────────────────────────────────────────
  options.services.mcp-servers = {
    servers = mapAttrs (name: serverDef:
      mkOption {
        type = types.submodule (mkServerModule name serverDef);
        default = {};
        description = "Configuration for the ${name} MCP server.";
      })
    serverFiles;

    mcpConfig = mkOption {
      type = types.attrsOf types.anything;
      internal = true;
      description = ''
        Generated mcp.json-compatible configuration from enabled servers.
        Reference as `config.services.mcp-servers.mcpConfig` from other modules, e.g.:

            home.file.".config/claude/mcp.json".text =
              builtins.toJSON config.services.mcp-servers.mcpConfig;
      '';
    };

    tools = mkOption {
      type = types.attrsOf (types.listOf types.str);
      readOnly = true;
      description = ''
        Tool names exposed by each enabled server (from upstream metadata).
        Use this to build client-specific auto-approval configs by filtering
        and formatting with standard Nix functions or `lib.mapTools`.
      '';
    };
  };

  # ── Implementation ─────────────────────────────────────────────────
  config = {
    services.mcp-servers.mcpConfig.mcpServers =
      mapAttrs mkHttpEntry enabledServers;

    services.mcp-servers.tools =
      mapAttrs (name: _: serverFiles.${name}.meta.tools or []) enabledServers;

    assertions = [];

    systemd.user.services = mapAttrs' (name: srv: let
      srvEnv = effectiveEnv name srv "http";
      srvArgs = effectiveArgs name srv "http";
      credVars = credentialVarsFor name;
      evaluatedSettings = mcpLib.evalSettings name srv.settings;
      serverDef = serverFiles.${name};
      usesHeaderAuth = (serverDef.meta.httpAuth or null) == "header";
      # Only inject credentials into the service env for servers without client-side header auth
      hasCreds = !usesHeaderAuth && mcpLib.hasCredentials credVars evaluatedSettings;
      baseCmd = concatStringsSep " " (
        map escapeShellArg (
          [(getExe srv.package) "--http"]
          ++ optionals (srvArgs != []) (["--"] ++ srvArgs)
        )
      );
      execStart =
        if hasCreds
        then
          toString (pkgs.writeShellScript ("mcp-" + name + "-start") ''
            set -euETo pipefail
            shopt -s inherit_errexit 2>/dev/null || :
            ${mcpLib.mkCredentialsSnippet credVars evaluatedSettings}
            exec ${baseCmd}
          '')
        else baseCmd;
    in
      nameValuePair ("mcp-" + name) {
        Unit = {
          Description = name + " MCP server";
          After = ["network.target"];
        };
        Service = {
          Type = "simple";
          ExecStart = execStart;
          Restart = "on-failure";
          RestartSec = 5;
          Environment =
            [("MCP_PORT=" + toString srv.service.port)]
            ++ mapAttrsToList (k: v: k + "=" + escapeShellArg v) srvEnv;
        };
        Install = {
          WantedBy = ["default.target"];
        };
      })
    serviceServers;
  };
}
