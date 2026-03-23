{lib, ...}: let
  inherit (lib) mkOption types optionalAttrs;
in {
  meta = {
    modes = ["stdio" "http"];
    scope = "remote";
    defaultPort = 19753;
    tools = ["kagi_search_fetch" "kagi_summarizer"];
  };

  settingsOptions = {
    apiKey = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Kagi API key for authentication. Required.";
    };

    summarizerEngine = mkOption {
      type = types.nullOr (types.enum ["cecil" "agnes" "daphne" "muriel"]);
      default = null;
      description = "Summarization engine to use. Defaults to cecil.";
    };
  };

  settingsToEnv = cfg:
    optionalAttrs (cfg.settings.apiKey != null) {
      KAGI_API_KEY = cfg.settings.apiKey;
    }
    // optionalAttrs (cfg.settings.summarizerEngine != null) {
      KAGI_SUMMARIZER_ENGINE = cfg.settings.summarizerEngine;
    };

  settingsToArgs = _cfg: [];
}
