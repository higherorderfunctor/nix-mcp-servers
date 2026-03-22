{lib, ...}: {
  meta = {
    modes = ["stdio"];
    scope = "remote";
    defaultPort = null;
    tools = ["effect_docs_search" "get_effect_doc"];
  };

  settingsOptions = {};

  settingsToEnv = _cfg: {};
  settingsToArgs = _cfg: [];
}
