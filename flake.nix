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
    overlays.default = import ./overlays {inherit inputs;};

    homeManagerModules.default = import ./modules/home-manager.nix;

    lib = let
      mcpLib = import ./lib {inherit (nixpkgs) lib;};
    in {
      # Generate an mcp.json-compatible attrset from a flat server map.
      #
      # Each value must have at minimum: { type, command?, args?, env?, url? }
      #
      # Example:
      #   mkMcpConfig {
      #     nixos-mcp = { type = "stdio"; command = lib.getExe pkgs.nix-mcp-servers.nixos-mcp; args = ["--stdio"]; };
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

      # Load a server definition by name (read-only introspection).
      #
      # Type: String -> { meta, settingsOptions, settingsToEnv, settingsToArgs }
      inherit (mcpLib) loadServer;

      # Build a single stdio mcp.json entry with validated settings.
      # Server name is derived from package.pname.
      #
      # Type: pkgs -> { package, settings?, env?, args? } -> AttrSet
      #
      # Example:
      #   mkStdioEntry pkgs { package = pkgs.nix-mcp-servers.nixos-mcp; }
      #   => { type = "stdio"; command = "/nix/store/...-nixos-mcp/bin/mcp-nixos"; args = [...]; }
      inherit (mcpLib) mkStdioEntry;

      # Build a single http mcp.json entry with validated settings.
      #
      # Type: { name, host?, port?, settings? } -> AttrSet
      #
      # Example:
      #   mkHttpEntry { name = "nixos-mcp"; port = 19752; }
      #   => { type = "http"; url = "http://127.0.0.1:19752"; }
      inherit (mcpLib) mkHttpEntry;

      # Build a complete mcp.json config for multiple stdio servers.
      #
      # Type: pkgs -> AttrSet -> AttrSet
      #
      # Example:
      #   mkStdioConfig pkgs {
      #     nixos-mcp = {};
      #   }
      #   => { mcpServers = { nixos-mcp = { ... }; }; }
      inherit (mcpLib) mkStdioConfig;

      # Pre-baked config entries for external HTTP-only MCP servers.
      # These run on remote infrastructure — no local package or service needed.
      #
      # Example:
      #   mcpServers = {
      #     inherit (inputs.nix-mcp-servers.lib.externalServers) aws-mcp;
      #   };
      externalServers = {
        aws-mcp = {
          type = "http";
          url = "https://knowledge-mcp.global.api.aws";
        };
      };
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
          cp ${self}/statix.toml .
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

      lib-stdio-entry = let
        testPkgs = import nixpkgs {
          inherit system;
          overlays = [self.overlays.default];
        };
        entry = self.lib.mkStdioEntry testPkgs {
          package = testPkgs.nix-mcp-servers.nixos-mcp;
        };
        entryJson = builtins.toJSON entry;
      in
        pkgs.runCommand "check-lib-stdio-entry" {} ''
          # Verify mkStdioEntry produces expected fields outside HM
          echo '${entryJson}' | ${pkgs.jq}/bin/jq -e '.type == "stdio"'
          echo '${entryJson}' | ${pkgs.jq}/bin/jq -e '.command | length > 0'
          echo '${entryJson}' | ${pkgs.jq}/bin/jq -e '.args | type == "array"'
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
              services.mcp-servers.servers = {
                fetch-mcp.enable = true;
                nixos-mcp.enable = true;
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
      servers = pkgs.nix-mcp-servers;
    in {
      # Raw packages — flat for CLI ergonomics
      inherit
        (servers)
        context7-mcp
        effect-mcp
        fetch-mcp
        git-intel-mcp
        git-mcp
        github-mcp
        kagi-mcp
        mcp-proxy
        nixos-mcp
        openmemory-mcp
        sequential-thinking-mcp
        sympy-mcp
        ;
    });

    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);
  };
}
