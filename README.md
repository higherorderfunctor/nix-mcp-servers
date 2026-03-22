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

Run all linting and evaluation checks:

```sh
nix flake check
```
