{lib, ...}: {
  meta = {
    modes = ["stdio"];
    scope = "remote";
    defaultPort = null;
    tools = ["sequentialthinking"];
  };

  settingsOptions = {};

  settingsToEnv = _cfg: {};
  settingsToArgs = _cfg: [];
}
