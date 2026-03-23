{
  lib,
  mcpLib,
  ...
}: let
  inherit (lib) mkOption types optionalAttrs;
in {
  meta = {
    modes = {
      stdio = "openmemory-mcp";
      http = "openmemory-mcp-serve";
    };
    scope = "remote";
    defaultPort = 19758;
    credentialVars = {
      credentials = {
        envVar = "OM_API_KEY";
        required = false;
      };
      openaiCredentials = {
        envVar = "OPENAI_API_KEY";
        required = false;
      };
    };
    tools = ["openmemory_delete" "openmemory_get" "openmemory_list" "openmemory_query" "openmemory_reinforce" "openmemory_store"];
  };

  settingsOptions = {
    credentials = mcpLib.mkCredentialsOption "OM_API_KEY";
    openaiCredentials = mcpLib.mkCredentialsOption "OPENAI_API_KEY";

    path = mkOption {
      type = types.str;
      default = "/mcp";
      description = "HTTP endpoint path. Only used in HTTP mode.";
    };

    tier = mkOption {
      type = types.enum ["hybrid" "fast" "smart" "deep"];
      default = "hybrid";
      description = "Performance tier for the memory system.";
    };

    embeddingsProvider = mkOption {
      type = types.nullOr (types.enum ["openai" "gemini" "aws" "ollama" "local" "synthetic"]);
      default = null;
      description = "Embedding provider. Server default is synthetic.";
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

  settingsToEnv = cfg: mode:
    {
      OM_TIER = cfg.settings.tier;
    }
    // optionalAttrs (mode == "http") {
      OM_PORT = toString cfg.service.port;
    }
    // optionalAttrs (cfg.settings.embeddingsProvider != null) {
      OM_EMBEDDINGS = cfg.settings.embeddingsProvider;
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

  settingsToArgs = _cfg: _mode: [];
}
