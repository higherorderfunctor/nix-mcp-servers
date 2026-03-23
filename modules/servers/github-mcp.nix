{lib, ...}: let
  inherit (lib) mkOption types concatStringsSep optional optionalAttrs optionals;
in {
  meta = {
    modes = ["stdio" "http"];
    scope = "remote";
    defaultPort = 19751;
    tools = ["add_issue_comment" "create_branch" "create_or_update_file" "create_pull_request" "create_repository" "delete_file" "fork_repository" "get_code_scanning_alert" "get_commit" "get_file_contents" "get_issue" "get_latest_release" "get_me" "get_release_by_tag" "get_tag" "list_branches" "list_code_scanning_alerts" "list_commits" "list_issues" "list_pull_requests" "list_releases" "list_tags" "merge_pull_request" "push_files" "search_code" "search_issues" "search_pull_requests" "search_repositories" "search_users" "update_pull_request" "update_pull_request_branch"];
  };

  settingsOptions = {
    personalAccessToken = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "GitHub personal access token. Required for stdio mode.";
    };

    ghHost = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "GitHub hostname for GHE Server or data residency (e.g. https://ghes.example.com).";
    };

    toolsets = mkOption {
      type = types.listOf (types.enum [
        "all"
        "default"
        "context"
        "repos"
        "issues"
        "pull_requests"
        "users"
        "actions"
        "code_security"
        "experiments"
        "notifications"
        "stargazers"
        "gists"
        "orgs"
        "discussions"
        "packages"
        "pages"
        "projects"
        "releases"
        "search"
        "secret_protection"
        "sub_issues"
      ]);
      default = [];
      description = ''
        Toolset groups to enable. Empty list uses the server default (context, repos,
        issues, pull_requests, users). Use "all" to enable everything.
      '';
    };

    tools = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Individual tool names to enable (additive with toolsets).";
    };

    excludeTools = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Tool names to forcibly disable regardless of other settings.";
    };

    dynamicToolsets = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = "Enable dynamic toolsets discovery.";
    };

    readOnly = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = "Restrict to read-only operations.";
    };

    logFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Path to a log file.";
    };

    enableCommandLogging = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = "Log all command requests and responses.";
    };

    contentWindowSize = mkOption {
      type = types.nullOr types.ints.positive;
      default = null;
      description = "Content window size. Server default is 5000.";
    };
  };

  settingsToEnv = cfg:
    optionalAttrs (cfg.settings.personalAccessToken != null) {
      GITHUB_PERSONAL_ACCESS_TOKEN = cfg.settings.personalAccessToken;
    };

  settingsToArgs = cfg:
  # transport-specific
    optionals (cfg.transport == "http" && cfg.port != null) ["--port" (toString cfg.port)]
    # toolsets and tools
    ++ optionals (cfg.settings.toolsets != []) ["--toolsets" (concatStringsSep "," cfg.settings.toolsets)]
    ++ optionals (cfg.settings.tools != []) ["--tools" (concatStringsSep "," cfg.settings.tools)]
    ++ optionals (cfg.settings.excludeTools != []) ["--exclude-tools" (concatStringsSep "," cfg.settings.excludeTools)]
    # flags
    ++ optional (cfg.settings.dynamicToolsets or false) "--dynamic-toolsets"
    ++ optional (cfg.settings.readOnly or false) "--read-only"
    ++ optional (cfg.settings.enableCommandLogging or false) "--enable-command-logging"
    # value flags
    ++ optional (cfg.settings.ghHost != null) "--gh-host=${cfg.settings.ghHost}"
    ++ optional (cfg.settings.logFile != null) "--log-file=${cfg.settings.logFile}"
    ++ optionals (cfg.settings.contentWindowSize != null) ["--content-window-size" (toString cfg.settings.contentWindowSize)];
}
