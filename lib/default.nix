{lib}: let
  inherit
    (lib)
    concatMapStringsSep
    evalModules
    getExe
    mapAttrs
    optionalAttrs
    optionals
    ;

  # ── Load a server definition by name ───────────────────────────────
  # Loads on demand — no centralized server list needed in lib.
  # The server list lives in modules/home-manager.nix (for HM) or is
  # implicit from the caller's attrset keys (for standalone mkStdioConfig).
  loadServer = name: import ../modules/servers/${name}.nix {inherit lib;};

  isExternal = serverDef: serverDef.meta ? external && serverDef.meta.external;

  # ── Evaluate settings through the module system ──────────────────
  evalSettings = name: settings: let
    serverDef = loadServer name;
    eval = evalModules {
      modules = [
        {options = serverDef.settingsOptions;}
        {config = settings;}
      ];
    };
  in
    eval.config;

  # ── Build a cfg-compatible attrset for server definitions ────────
  # Server settingsToEnv/settingsToArgs expect { settings; service; }
  # For stdio mode, service.* is never accessed (guarded by mode == "http")
  mkCfgShim = {
    evaluatedSettings,
    port ? null,
    host ? "127.0.0.1",
  }: {
    settings = evaluatedSettings;
    service = {inherit port host;};
  };

  # ── Effective env/args (settings + escape hatches) ─────────────────
  effectiveEnv = name: cfgShim: mode: extraEnv: let
    serverDef = loadServer name;
  in
    (serverDef.settingsToEnv cfgShim mode) // extraEnv;

  effectiveArgs = name: cfgShim: mode: extraArgs: let
    serverDef = loadServer name;
  in
    (serverDef.settingsToArgs cfgShim mode) ++ extraArgs;

  # ── Secrets wrapper for stdio servers with environmentFiles ────────
  mkSecretsWrapper = pkgs: name: package: environmentFiles:
    pkgs.writeShellScript (name + "-env") ''
      set -euETo pipefail
      shopt -s inherit_errexit 2>/dev/null || :
      ${concatMapStringsSep "\n" (f: ''set -a; . "${f}"; set +a'') environmentFiles}
      exec "${getExe package}" "$@"
    '';

  # ── mcp.json entry builders ─────────────────────────────────────
  mkStdioEntry = pkgs: {
    name,
    package ? pkgs.${name},
    settings ? {},
    env ? {},
    args ? [],
    environmentFiles ? [],
  }: let
    evaluatedSettings = evalSettings name settings;
    cfgShim = mkCfgShim {inherit evaluatedSettings;};
    srvEnv = effectiveEnv name cfgShim "stdio" env;
    srvArgs = effectiveArgs name cfgShim "stdio" args;
    hasEnvFiles = environmentFiles != [];
  in
    {
      type = "stdio";
      command =
        if hasEnvFiles
        then toString (mkSecretsWrapper pkgs name package environmentFiles)
        else getExe package;
      args = ["--stdio"] ++ optionals (srvArgs != []) (["--"] ++ srvArgs);
    }
    // optionalAttrs (srvEnv != {}) {env = srvEnv;};

  mkHttpEntry = {
    name,
    host ? "127.0.0.1",
    port ? null,
    settings ? {},
  }: let
    serverDef = loadServer name;
    evaluatedSettings = evalSettings name settings;
  in
    if isExternal serverDef
    then {
      type = "http";
      url = evaluatedSettings.url;
    }
    else {
      type = "http";
      url =
        "http://"
        + host
        + ":"
        + toString port
        + (evaluatedSettings.path or "");
    };

  # ── Convenience: multiple servers at once ──────────────────────────
  mkStdioConfig = pkgs: serverConfigs: {
    mcpServers =
      mapAttrs (name: cfg: mkStdioEntry pkgs ({inherit name;} // cfg))
      serverConfigs;
  };
in {
  inherit
    effectiveArgs
    effectiveEnv
    evalSettings
    isExternal
    loadServer
    mkCfgShim
    mkHttpEntry
    mkSecretsWrapper
    mkStdioConfig
    mkStdioEntry
    ;
}
