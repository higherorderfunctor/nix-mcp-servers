{
  lib,
  mcpLib,
  ...
}: let
  inherit (lib) mkOption types optionalAttrs;
in {
  meta = {
    modes = ["stdio" "http"];
    scope = "remote";
    defaultPort = 19753;
    credentialVars = {credentials = "KAGI_API_KEY";};
    tools = ["kagi_search_fetch" "kagi_summarizer"];
  };

  settingsOptions = {
    credentials = mcpLib.mkCredentialsOption "KAGI_API_KEY";

    summarizerEngine = mkOption {
      type = types.nullOr (types.enum ["cecil" "agnes" "daphne" "muriel"]);
      default = null;
      description = "Summarization engine to use. Defaults to cecil.";
    };
  };

  settingsToEnv = cfg: _mode:
    optionalAttrs (cfg.settings.summarizerEngine != null) {
      KAGI_SUMMARIZER_ENGINE = cfg.settings.summarizerEngine;
    };

  settingsToArgs = _cfg: _mode: [];
}
