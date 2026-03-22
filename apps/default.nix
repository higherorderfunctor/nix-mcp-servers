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
  update = mkApp "update" (with pkgs; [
    curl
    git
    jq
    nodejs
    nvfetcher
    prefetch-npm-deps
  ]);
}
