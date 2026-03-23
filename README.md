# nix-mcp-servers

A collection of ready-to-use [MCP servers](https://modelcontextprotocol.io) packaged with Nix.

## Quick Start

Add as a flake input:

```nix
{
  inputs.nix-mcp-servers = {
    url = "github:caubut/nix-mcp-servers";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

Apply the overlay:

```nix
overlays = [ inputs.nix-mcp-servers.overlays.default ];
```

To use a single server's overlay instead of all:

```nix
overlays = [ inputs.nix-mcp-servers.overlays."<server-name>" ];
```

### Binary cache

Pre-built binaries are available via [Cachix](https://app.cachix.org/cache/hof-nix-mcp-servers). Add the cache to skip building from source:

```nix
# NixOS
nix.settings = {
  extra-substituters = [ "https://hof-nix-mcp-servers.cachix.org" ];
  extra-trusted-public-keys = [ "hof-nix-mcp-servers.cachix.org-1:UeB1pQXJ3uQHKVDB8zsbztxmzBBqcTrIAKGGv3AWwPY=" ];
};
```

For non-NixOS systems, add to `~/.config/nix/nix.conf`:

```ini
extra-substituters = https://hof-nix-mcp-servers.cachix.org
extra-trusted-public-keys = hof-nix-mcp-servers.cachix.org-1:UeB1pQXJ3uQHKVDB8zsbztxmzBBqcTrIAKGGv3AWwPY=
```

## Home Manager

Enable the module and configure servers declaratively:

```nix
{
  imports = [ inputs.nix-mcp-servers.homeManagerModules.default ];

  services.mcp-servers.servers.<server-name>.enable = true;
}
```

Write the generated config to your MCP client:

```nix
home.file.".config/claude/mcp.json".text =
  builtins.toJSON config.services.mcp-servers.mcpConfig;
```

Enabling a server creates a systemd HTTP service and an HTTP entry in `mcpConfig`. Servers without native HTTP support use [mcp-proxy](https://github.com/sparfenyuk/mcp-proxy) as a stdio-to-HTTP bridge automatically.

For stdio-only configs (devShells, non-HM systems), use `lib.mkStdioConfig` or `lib.mkStdioEntry` directly — see [Without Home Manager](#without-home-manager).

## Tool Permissions

The module exposes `config.services.mcp-servers.tools` — an attrset of each enabled server's tool names. Use this to build client-specific auto-approval configs.

### Claude Code

Generate `permissions.allow` entries for `~/.claude/settings.json`:

```nix
let
  approved = {
    <server-name> = config.services.mcp-servers.tools.<server-name>;
  };
in {
  home.file.".claude/settings.json".text = builtins.toJSON {
    permissions.allow =
      inputs.nix-mcp-servers.lib.mapTools
        (server: tool: "mcp__${server}__${tool}")
        approved;
  };
}
```

### Generic JSON

Export approved tools as JSON for any MCP client:

```nix
home.file.".config/mcp-approved-tools.json".text = builtins.toJSON {
  <server-name> = config.services.mcp-servers.tools.<server-name>;
};
```

### CLI flags

Generate a comma-separated list for tools that accept `--allowedTools` or similar:

```nix
let
  allTools = inputs.nix-mcp-servers.lib.mapTools (_: tool: tool)
    config.services.mcp-servers.tools;
in
  lib.concatStringsSep "," allTools
```

## Without Home Manager

### Typed config with `mkStdioConfig`

Use `lib.mkStdioConfig` for validated settings without Home Manager — works in devShells, repo flakes, and non-HM systems:

```nix
let
  mcp = inputs.nix-mcp-servers.lib.mkStdioConfig pkgs {
    nixos-mcp = {};
  };
in
  builtins.toJSON mcp
# => { mcpServers = { nixos-mcp = { type = "stdio"; ... }; }; }
```

For servers that need secrets at runtime:

```nix
mcpConfig.mcpServers.github-mcp =
  inputs.nix-mcp-servers.lib.mkStdioEntry pkgs {
    name = "github-mcp";
    environmentFiles = [ "/run/secrets/github-token" ];
    settings = { readOnly = true; };
  };
```

### Manual config with `mkMcpConfig`

For full control without typed settings, use `lib.mkMcpConfig` with raw entries:

```nix
let
  mcp = inputs.nix-mcp-servers.lib.mkMcpConfig {
    <server-name> = {
      type = "stdio";
      command = lib.getExe pkgs.<server-name>;
      args = [ "--stdio" ];
    };
  };
in
  builtins.toJSON mcp
```

## Available Servers

| Server                                                    | Description                          | Transport   |
| --------------------------------------------------------- | ------------------------------------ | ----------- |
| [nixos-mcp](https://github.com/utensils/mcp-nixos)        | NixOS / Home Manager / nix ecosystem | stdio, http |
| [github-mcp](https://github.com/github/github-mcp-server) | GitHub API                           | stdio, http |

| [kagi-mcp](https://github.com/kagisearch/kagi-mcp) | Kagi search and summarization | stdio, http |

| [openmemory-mcp](https://github.com/CaviraOSS/OpenMemory) | OpenMemory long-term memory | stdio |

| [sequential-thinking-mcp](https://github.com/modelcontextprotocol/servers) | Sequential thinking | stdio |

| [sympy-mcp](https://github.com/sdiehl/sympy-mcp) | SymPy math | stdio |

All binaries use a unified interface:

```sh
<package> --stdio [-- extra-args...]
<package> --http [-- extra-args...]   # only where Transport includes http
<package> --version
```

Servers marked **(local)** operate on the local filesystem and should not be proxied to HTTP.

## HTTP-only Servers

Remote MCP servers that need no local packaging — configure directly in `mcp.json` with `"type": "http"`.

| Server                                                                           | URL                                    |
| -------------------------------------------------------------------------------- | -------------------------------------- |
| [AWS Knowledge](https://awslabs.github.io/mcp/servers/aws-knowledge-mcp-server/) | `https://knowledge-mcp.global.api.aws` |

## Updating

```sh
nix run .#update
```

Updates flake inputs, refreshes upstream versions via nvfetcher, regenerates lock files and hashes, then verifies with `nix flake show`.

## Contributing

Issues and PRs for new servers are welcome.

### Prerequisites

- [Nix](https://nixos.org/) with flakes enabled
- Optional: [direnv](https://direnv.net/) with
  [nix-direnv](https://github.com/nix-community/nix-direnv) to automatically
  load the flake dev shell (`.envrc` uses `use flake` which requires nix-direnv)

### Development

Enter the dev shell for all tools (linters, formatters, LSPs, nvfetcher):

```sh
nix develop
```

Check for tool drift (detects added/removed tools in upstream servers):

```sh
nix run .#check-drift
```

Run all linting and evaluation checks:

```sh
nix flake check
```

### Agentic workflows

The repo is set up for AI-assisted maintenance using [GitHub Copilot CLI](https://github.com/features/copilot/cli) or [Claude Code](https://claude.ai/code). Both can read `CLAUDE.md` for project conventions.

To autofix a drift report locally:

```sh
# Run drift detection (logs visible on stderr, JSON report saved)
nix run .#check-drift > >(tee /tmp/drift-report.json) 2> >(tee /tmp/drift-log.txt >&2)

# Feed to Copilot CLI (with Claude model) to fix
gh copilot --model claude-sonnet-4.6
# Then: "Fix the tool drift in /tmp/drift-report.json per CLAUDE.md"

# Or with Claude Code
claude
# Then: "Fix the tool drift in /tmp/drift-report.json per CLAUDE.md"
```
