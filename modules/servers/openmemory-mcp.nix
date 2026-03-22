{lib, ...}: let
  inherit (lib) mkOption types optionalAttrs;
in {
  meta = {
    modes = ["stdio"];
    scope = "remote";
    defaultPort = null;
    tools = ["openmemory_delete" "openmemory_get" "openmemory_list" "openmemory_query" "openmemory_reinforce" "openmemory_store"];
  };

  settingsOptions = {
    tier = mkOption {
      type = types.enum ["hybrid" "fast" "smart" "deep"];
      default = "hybrid";
      description = "Performance tier for the memory system.";
    };

    apiKey = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "API authentication key. Disables auth if empty/unset.";
    };

    embeddingsProvider = mkOption {
      type = types.nullOr (types.enum ["openai" "gemini" "aws" "ollama" "local" "synthetic"]);
      default = null;
      description = "Embedding provider. Server default is synthetic.";
    };

    openaiApiKey = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "OpenAI API key. Required when embeddingsProvider is openai.";
    };

    metadataBackend = mkOption {
      type = types.nullOr (types.enum ["sqlite" "postgres"]);
      default = null;
      description = "Metadata storage backend. Server default is sqlite.";
    };

    dbPath = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "SQLite database file path (when metadataBackend is sqlite).";
    };

    vectorBackend = mkOption {
      type = types.nullOr (types.enum ["sqlite" "postgres" "valkey"]);
      default = null;
      description = "Vector storage backend.";
    };
  };

  settingsToEnv = cfg:
    {
      OM_TIER = cfg.settings.tier;
    }
    // optionalAttrs (cfg.settings.apiKey != null) {
      OM_API_KEY = cfg.settings.apiKey;
    }
    // optionalAttrs (cfg.settings.embeddingsProvider != null) {
      OM_EMBEDDINGS = cfg.settings.embeddingsProvider;
    }
    // optionalAttrs (cfg.settings.openaiApiKey != null) {
      OPENAI_API_KEY = cfg.settings.openaiApiKey;
    }
    // optionalAttrs (cfg.settings.metadataBackend != null) {
      OM_METADATA_BACKEND = cfg.settings.metadataBackend;
    }
    // optionalAttrs (cfg.settings.dbPath != null) {
      OM_DB_PATH = cfg.settings.dbPath;
    }
    // optionalAttrs (cfg.settings.vectorBackend != null) {
      OM_VECTOR_BACKEND = cfg.settings.vectorBackend;
    };

  settingsToArgs = _cfg: [];
}
