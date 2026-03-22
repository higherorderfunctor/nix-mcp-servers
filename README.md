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

## Updating

```sh
nix run .#update
```

Updates flake inputs, refreshes upstream versions via nvfetcher, regenerates lock files and hashes, then verifies with `nix flake show`.

## Contributing

Issues and PRs for new servers are welcome.

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
