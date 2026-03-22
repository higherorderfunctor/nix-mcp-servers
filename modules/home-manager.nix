{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    concatMapStringsSep
    concatStringsSep
    escapeShellArg
    filterAttrs
    getExe
    map
    mapAttrs
    mapAttrs'
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    nameValuePair
    optionalAttrs
    optionals
    types
    ;

  cfg = config.services.mcp-servers;

  # ── Import per-server definitions ──────────────────────────────────
  serverFiles = mapAttrs (_: path: import path {inherit lib;}) {
    context7-mcp = ./servers/context7-mcp.nix;
    effect-mcp = ./servers/effect-mcp.nix;
    fetch-mcp = ./servers/fetch-mcp.nix;
    nixos-mcp = ./servers/nixos-mcp.nix;
  };

  # ── Per-server submodule ───────────────────────────────────────────
  mkServerModule = name: serverDef: _: {
    options = {
      enable = mkEnableOption "the ${name} MCP server";

      package = mkOption {
        type = types.package;
        default = pkgs.${name};
        defaultText = lib.literalExpression "pkgs.${name}";
        description = "The ${name} package to use.";
      };

      transport = mkOption {
        type = types.enum serverDef.meta.modes;
        default = "stdio";
        description = "Transport mode for ${name}. Supported: ${concatStringsSep ", " serverDef.meta.modes}.";
      };

      port = mkOption {
        type = types.nullOr types.port;
        default = serverDef.meta.defaultPort;
        description = "Port to bind when using HTTP transport.";
      };

      host = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Host/address to bind when using HTTP transport.";
      };

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
    };
  };

  # ── Derived sets ───────────────────────────────────────────────────
  enabledServers = filterAttrs (_: srv: srv.enable) cfg.servers;

  httpServiceServers =
    filterAttrs
    (_: srv: srv.scope == "remote" && srv.transport == "http")
    enabledServers;

  # ── Effective env/args (settings + escape hatches) ─────────────────
  effectiveEnv = name: srv: let
    serverDef = serverFiles.${name};
  in
    (serverDef.settingsToEnv srv) // srv.env;

  effectiveArgs = name: srv: let
    serverDef = serverFiles.${name};
  in
    (serverDef.settingsToArgs srv) ++ srv.args;

  # ── Secrets wrapper for stdio servers with environmentFiles ────────
  mkSecretsWrapper = name: srv:
    pkgs.writeShellScript "${name}-env" ''
      set -euETo pipefail
      shopt -s inherit_errexit 2>/dev/null || :
      ${concatMapStringsSep "\n" (f: ''set -a; . "${f}"; set +a'') srv.environmentFiles}
      exec "${getExe srv.package}" "$@"
    '';

  # ── mcp.json entry builder ────────────────────────────────────────
  mkMcpEntry = name: srv: let
    srvEnv = effectiveEnv name srv;
    srvArgs = effectiveArgs name srv;
    hasEnvFiles = srv.environmentFiles != [];
  in
    if srv.transport == "stdio"
    then
      {
        type = "stdio";
        command =
          if hasEnvFiles
          then "${mkSecretsWrapper name srv}"
          else getExe srv.package;
        args = ["--stdio"] ++ optionals (srvArgs != []) (["--"] ++ srvArgs);
      }
      // optionalAttrs (srvEnv != {}) {env = srvEnv;}
    else {
      type = "http";
      url = "http://${srv.host}:${toString srv.port}";
    };
in {
  # ── Options ────────────────────────────────────────────────────────
  options.services.mcp-servers = {
    enable = mkEnableOption "MCP server management via nix-mcp-servers";

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
  config = lib.mkMerge [
    {
      services.mcp-servers.mcpConfig.mcpServers = {};
      services.mcp-servers.tools = {};
    }
    (mkIf cfg.enable {
      services.mcp-servers.mcpConfig = {
        mcpServers = mapAttrs mkMcpEntry enabledServers;
      };

      services.mcp-servers.tools =
        mapAttrs (name: _: serverFiles.${name}.meta.tools or []) enabledServers;

      assertions =
        mapAttrsToList (name: srv: {
          assertion = srv.transport == "http" -> srv.port != null;
          message = "services.mcp-servers.servers.${name}: port is required when transport is \"http\"";
        })
        enabledServers
        ++ mapAttrsToList (name: srv: {
          assertion = srv.scope == "local" -> srv.transport == "stdio";
          message = "services.mcp-servers.servers.${name}: local-scoped servers only support stdio transport";
        })
        enabledServers;

      systemd.user.services = mapAttrs' (name: srv: let
        srvEnv = effectiveEnv name srv;
        srvArgs = effectiveArgs name srv;
      in
        nameValuePair "mcp-${name}" {
          Unit = {
            Description = "${name} MCP server";
            After = ["network.target"];
          };
          Service = {
            Type = "simple";
            ExecStart = concatStringsSep " " (
              map escapeShellArg (
                ["${getExe srv.package}" "--http"]
                ++ optionals (srvArgs != []) (["--"] ++ srvArgs)
              )
            );
            Restart = "on-failure";
            RestartSec = 5;
            Environment = mapAttrsToList (k: v: "${k}=${escapeShellArg v}") srvEnv;
            EnvironmentFile = srv.environmentFiles;
          };
          Install = {
            WantedBy = ["default.target"];
          };
        })
      httpServiceServers;
    })
  ];
}
