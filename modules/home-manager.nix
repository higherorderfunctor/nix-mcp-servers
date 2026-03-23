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
  serverFiles = mapAttrs (_: path: import path {inherit lib;}) {
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

        environmentFiles = mkOption {
          type = types.listOf types.str;
          default = [];
          description = ''
            Paths to files containing environment variables in KEY=VALUE format,
            read at runtime. Use for secrets (API keys, tokens) that should not
            be stored in the Nix store. Works with sops-nix, agenix, or any tool
            that produces environment files.
          '';
        };

        env = mkOption {
          type = types.attrsOf types.str;
          default = {};
          description = "Extra environment variables (escape hatch for options not yet in settings). Values end up in the Nix store — use environmentFiles for secrets.";
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
            type = types.nullOr types.port;
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

  # ── Derived sets ───────────────────────────────────────────────────
  enabledServers = filterAttrs (_: srv: srv.enable) cfg.servers;

  serviceServers =
    filterAttrs
    (name: _: !(isExternal serverFiles.${name}))
    enabledServers;

  # ── Delegate entry building to lib ─────────────────────────────────
  mkHttpEntry = name: srv:
    mcpLib.mkHttpEntry ({
        inherit name;
        settings = srv.settings;
      }
      // optionalAttrs (!(isExternal serverFiles.${name})) {
        inherit (srv.service) port host;
      });

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

    assertions =
      mapAttrsToList (name: srv: let
        serverDef = serverFiles.${name};
      in {
        assertion = isExternal serverDef || srv.service.port != null;
        message = "services.mcp-servers.servers.${name}: service.port is required for packaged servers";
      })
      enabledServers;

    systemd.user.services = mapAttrs' (name: srv: let
      srvEnv = effectiveEnv name srv "http";
      srvArgs = effectiveArgs name srv "http";
    in
      nameValuePair ("mcp-" + name) {
        Unit = {
          Description = name + " MCP server";
          After = ["network.target"];
        };
        Service = {
          Type = "simple";
          ExecStart = concatStringsSep " " (
            map escapeShellArg (
              [(getExe srv.package) "--http"]
              ++ optionals (srvArgs != []) (["--"] ++ srvArgs)
            )
          );
          Restart = "on-failure";
          RestartSec = 5;
          Environment =
            [("MCP_PORT=" + toString srv.service.port)]
            ++ mapAttrsToList (k: v: k + "=" + escapeShellArg v) srvEnv;
          EnvironmentFile = srv.environmentFiles;
        };
        Install = {
          WantedBy = ["default.target"];
        };
      })
    serviceServers;
  };
}
