{lib, ...}: {
  meta = {
    modes = ["stdio" "http"];
    scope = "remote";
    defaultPort = 19759;
    tools = ["sequentialthinking"];
  };

  settingsOptions = {};

  settingsToEnv = _cfg: _mode: {};
  settingsToArgs = _cfg: _mode: [];
}
