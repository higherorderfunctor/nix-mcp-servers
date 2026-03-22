{pkgs}: let
  mkApp = name: runtimeInputs: let
    app = pkgs.writeShellApplication {
      inherit name runtimeInputs;
      bashOptions = ["errexit" "nounset" "pipefail" "errtrace" "functrace"];
      text = builtins.readFile ./${name}.sh;
    };
  in {
    type = "app";
    program = "${app}/bin/${name}";
  };
in {
  check-drift = mkApp "check-drift" (with pkgs; [
    coreutils
    gnugrep
    jq
    nix
    python3
  ]);

  update = mkApp "update" (with pkgs; [
    alejandra
    curl
    git
    jq
    nodejs
    nvfetcher
    prefetch-npm-deps
  ]);
}
