{lib, ...}: {
  meta = {
    modes = ["stdio" "http"];
    scope = "remote";
    defaultPort = 19754;
    tools = ["effect_docs_search" "get_effect_doc"];
  };

  settingsOptions = {};

  settingsToEnv = _cfg: _mode: {};
  settingsToArgs = _cfg: _mode: [];
}
