{
  description = "Nix overlay packaging MCP servers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nvfetcher = {
      url = "github:berberman/nvfetcher";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    ...
  } @ inputs: let
    forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
  in {
    overlays.default = import ./overlays {inherit inputs;};

    devShells = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.mkShellNoCC {
        packages = [
          # Formatting
          pkgs.alejandra
          pkgs.dprint
          pkgs.shfmt

          # Linting
          pkgs.deadnix
          pkgs.shellcheck
          pkgs.shellharden
          pkgs.statix

          # LSPs
          pkgs.bash-language-server
          pkgs.marksman
          pkgs.nixd
          pkgs.taplo

          # Version tracking
          inputs.nvfetcher.packages.${system}.default
        ];
      };
    });

    checks = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      formatting =
        pkgs.runCommand "check-formatting" {
          nativeBuildInputs = [pkgs.alejandra pkgs.shfmt];
        } ''
          alejandra --check --exclude ${self}/overlays/.nvfetcher ${self} 2>/dev/null
          shfmt -d -i 0 -ci ${self}/apps/*.sh
          touch $out
        '';

      deadnix =
        pkgs.runCommand "check-deadnix" {
          nativeBuildInputs = [pkgs.deadnix];
        } ''
          deadnix --no-lambda-pattern-names --fail ${self} --exclude ${self}/overlays/.nvfetcher
          touch $out
        '';

      statix =
        pkgs.runCommand "check-statix" {
          nativeBuildInputs = [pkgs.statix];
        } ''
          statix check ${self} --ignore overlays/.nvfetcher
          touch $out
        '';

      shellcheck =
        pkgs.runCommand "check-shellcheck" {
          nativeBuildInputs = [pkgs.shellcheck];
        } ''
          shellcheck ${self}/apps/*.sh
          touch $out
        '';

      shellharden =
        pkgs.runCommand "check-shellharden" {
          nativeBuildInputs = [pkgs.shellharden];
        } ''
          shellharden --check ${self}/apps/*.sh
          touch $out
        '';
    });

    apps = forAllSystems (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [inputs.nvfetcher.overlays.default];
      };
    in
      import ./apps {inherit pkgs;});

    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);
  };
}
