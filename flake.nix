{
  description = "Nix overlay packaging MCP servers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nvfetcher = {
      url = "github:berberman/nvfetcher";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mcp-nixos = {
      url = "github:utensils/mcp-nixos";
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
    overlays = let
      inherit (nixpkgs) lib;
      import' = path: import path {inherit inputs;};
      sources = import' ./overlays/sources.nix;
      perPkg = name:
        lib.composeManyExtensions [sources (import' ./overlays/${name}.nix)];
    in {
      default = import ./overlays {inherit inputs;};
      context7-mcp = perPkg "context7-mcp";
      effect-mcp = perPkg "effect-mcp";
      nixos-mcp = perPkg "nixos-mcp";
    };

    homeManagerModules.default = import ./modules/home-manager.nix;

    lib = {
      # Generate an mcp.json-compatible attrset from a flat server map.
      #
      # Each value must have at minimum: { type, command?, args?, env?, url? }
      #
      # Example:
      #   mkMcpConfig {
      #     nixos-mcp = { type = "stdio"; command = lib.getExe pkgs.nixos-mcp; args = ["--stdio"]; };
      #   }
      #   => { mcpServers = { nixos-mcp = { ... }; }; }
      mkMcpConfig = servers: {mcpServers = servers;};

      # Map a function over every (server, tool) pair in a tools attrset.
      #
      # Type: (String -> String -> a) -> AttrSet -> [a]
      #
      # Example:
      #   mapTools (server: tool: "mcp__${server}__${tool}") { nixos-mcp = ["get_issue"]; }
      #   => [ "mcp__nixos-mcp__get_issue" ]
      mapTools = f: tools:
        nixpkgs.lib.concatLists (nixpkgs.lib.mapAttrsToList
          (server: toolList: map (tool: f server tool) toolList)
          tools);
    };

    devShells = forAllSystems (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [self.overlays.default];
      };
    in {
      default = pkgs.mkShellNoCC {
        packages =
          builtins.attrValues self.packages.${system}
          ++ [
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

      home-manager-module = let
        eval = nixpkgs.lib.evalModules {
          modules = [
            self.homeManagerModules.default
            {
              options = {
                assertions = nixpkgs.lib.mkOption {
                  type = nixpkgs.lib.types.listOf nixpkgs.lib.types.unspecified;
                  default = [];
                };
                systemd.user.services = nixpkgs.lib.mkOption {
                  type = nixpkgs.lib.types.attrsOf nixpkgs.lib.types.unspecified;
                  default = {};
                };
              };
              config._module.args.pkgs = import nixpkgs {
                inherit system;
                overlays = [self.overlays.default];
              };
            }
            {
              services.mcp-servers = {
                enable = true;
                servers = {};
              };
            }
          ];
        };
      in
        pkgs.runCommand "check-home-manager-module" {} ''
          # Verify mcpConfig evaluates and has expected structure
          test '${builtins.toJSON eval.config.services.mcp-servers.mcpConfig}' != '{}'
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

    packages = forAllSystems (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [self.overlays.default];
      };
    in {
      inherit
        (pkgs)
        context7-mcp
        effect-mcp
        nixos-mcp
        ;
    });

    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);
  };
}
