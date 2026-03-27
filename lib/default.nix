{lib}: let
  inherit
    (lib)
    any
    concatStringsSep
    evalModules
    getExe
    mapAttrs
    mapAttrsToList
    mkOption
    optionalAttrs
    optionals
    types
    ;

  # ── Load a server definition by name ───────────────────────────────
  # Loads on demand — no centralized server list needed in lib.
  # The server list lives in modules/home-manager.nix (for HM) or is
  # implicit from the caller's attrset keys (for standalone mkStdioConfig).
  loadServer = name: import ../modules/servers/${name}.nix {inherit lib mcpLib;};
  mcpLib = {inherit mkCredentialsOption;};

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

  # ── Credentials option generator ──────────────────────────────────
  # Creates a flat { file; helper; } submodule option for a single credential.
  # The raw secret value is read at runtime and exported as envVar.
  # Servers with one credential use this as `credentials`, servers with
  # multiple credentials use distinct option names (e.g., credentials,
  # openaiCredentials) — each mapping to one env var.
  mkCredentialsOption = envVar:
    mkOption {
      type = types.submodule {
        options = {
          file = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Path to a file containing the raw secret value, read at runtime.
              Not stored in the Nix store. Works with sops-nix, agenix, or any
              tool that decrypts secrets to files. Mapped to ${envVar}.
            '';
          };
          helper = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Path to an executable that outputs the raw secret value on stdout.
              Executed at service start. Mapped to ${envVar}.
            '';
          };
        };
      };
      default = {};
      description = "Credential mapped to ${envVar}.";
    };

  # ── Credentials helpers ──────────────────────────────────────────
  # credentialVars: { settingsOptionName = "ENV_VAR"; } from meta.credentialVars
  # settings: evaluated settings attrset — credentialVars keys are looked up here

  hasCredentials = credentialVars: settings:
    any (optName: let
      cred = settings.${optName};
    in
      (cred.file or null) != null || (cred.helper or null) != null)
    (builtins.attrNames credentialVars);

  mkCredentialsSnippet = credentialVars: settings:
    concatStringsSep "\n" (mapAttrsToList (optName: envVar: let
      cred = settings.${optName};
    in
      if cred.helper or null != null
      then ''export ${envVar}="$("${cred.helper}")"''
      else if cred.file or null != null
      then ''export ${envVar}="$(cat "${cred.file}")"''
      else "")
    credentialVars);

  # ── Headers helper for HTTP servers with client-side auth ──────────
  # Generates a script that outputs JSON headers for MCP clients.
  # The first credential is used as a Bearer token in the Authorization header.
  mkHeadersHelper = pkgs: name: credentialVars: settings: let
    # Use the first credential entry that has a value set
    firstCredName = builtins.head (builtins.attrNames credentialVars);
    cred = settings.${firstCredName};
    readToken =
      if cred.helper or null != null
      then ''"$("${cred.helper}")"''
      else if cred.file or null != null
      then ''"$(cat "${cred.file}")"''
      else ''""'';
  in
    toString (pkgs.writeShellScript ("mcp-" + name + "-headers") ''
      set -euETo pipefail
      shopt -s inherit_errexit 2>/dev/null || :
      TOKEN=${readToken}
      printf '{"Authorization": "Bearer %s"}\n' "$TOKEN"
    '');

  # ── Secrets wrapper for stdio servers with credentials ─────────────
  mkSecretsWrapper = pkgs: name: package: credentialVars: settings:
    pkgs.writeShellScript (name + "-env") ''
      set -euETo pipefail
      shopt -s inherit_errexit 2>/dev/null || :
      ${mkCredentialsSnippet credentialVars settings}
      exec "${getExe package}" "$@"
    '';

  # ── mcp.json entry builders ─────────────────────────────────────
  mkStdioEntry = pkgs: {
    name,
    package ? pkgs.${name},
    settings ? {},
    env ? {},
    args ? [],
  }: let
    serverDef = loadServer name;
    evaluatedSettings = evalSettings name settings;
    cfgShim = mkCfgShim {inherit evaluatedSettings;};
    srvEnv = effectiveEnv name cfgShim "stdio" env;
    srvArgs = effectiveArgs name cfgShim "stdio" args;
    credentialVars = serverDef.meta.credentialVars or {};
    needsWrapper = hasCredentials credentialVars evaluatedSettings;
  in
    {
      type = "stdio";
      command =
        if needsWrapper
        then toString (mkSecretsWrapper pkgs name package credentialVars evaluatedSettings)
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
    hasCredentials
    isExternal
    loadServer
    mkCfgShim
    mkCredentialsOption
    mkCredentialsSnippet
    mkHeadersHelper
    mkHttpEntry
    mkSecretsWrapper
    mkStdioConfig
    mkStdioEntry
    ;
}
