# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

nix-mcp-servers is a Nix flake that packages Model Context Protocol (MCP) servers as Nix derivations with a unified CLI interface. It provides a composable overlay, per-package overlays, and a Home Manager module for declarative configuration.

## Build & Validation Commands

```bash
nix flake show                # List all outputs (quick validation)
nix build .#<package-name>    # Build a specific package (e.g., .#context7-mcp)
nix flake check               # Full flake evaluation check
nix develop                   # Enter devShell with all packages available
nix run .#update              # Full update pipeline: flake inputs, nvfetcher, locks, hashes
nix fmt                       # Format all Nix files with alejandra
```

CI runs `nix flake check` and a per-package build matrix on every PR and push to main.

## Architecture

### Flake Structure

- **flake.nix** — Defines inputs, composes the overlay, exports packages, devShell, and `homeManagerModules.default`.
- **overlays/default.nix** — Composes all per-package overlays via `lib.composeManyExtensions`.
- **overlays/sources.nix** — Overlay that exposes `final.nv-sources.<name>` from nvfetcher's `generated.nix` merged with `hashes.json`.
- **modules/home-manager.nix** — Home Manager module with `services.mcp-servers` options, generates `mcp.json` and systemd services.
- **overlays/mk-mcp-wrapper.nix** — Shared wrapper that gives every server a uniform `--stdio` / `--http` CLI.

## Commit Convention

This project uses [Conventional Commits](https://www.conventionalcommits.org/). Every commit message must follow this format:

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

**Types:** `feat`, `fix`, `refactor`, `docs`, `chore`, `build`, `ci`, `style`, `perf`, `test`

**Scopes** (optional but encouraged): package name (e.g., `context7-mcp`, `github-mcp`), `overlay`, `module`, `flake`, `update`, `wrapper`

**Examples:**

- `feat(kagi-mcp): add kagi MCP server package`
- `fix(update): correct npmDepsHash prefetch step`
- `chore: update flake inputs and nvfetcher sources`
- `refactor(wrapper): simplify mkMcpWrapper dispatch logic`
- `docs: update CLAUDE.md with conventional commits guide`

### Version Tracking

- **nvfetcher.toml** — Defines upstream sources (PyPI, npm registry, GitHub) for each package
- **overlays/.nvfetcher/generated.nix** — Auto-generated Nix expressions with fetchers (managed by `nvfetcher`, do not edit)
- **overlays/.nvfetcher/generated.json** — Raw JSON metadata (managed by `nvfetcher`, do not edit)
- **overlays/sources.nix** — Overlay that calls `generated.nix` with fetchers and merges sidecar hashes, exposing `final.nv-sources.<name>`
- **overlays/hashes.json** — Sidecar file for computed hashes (`npmDepsHash`, `vendorHash`) managed by the update script

### Upstream Version Strategy

Choose the tracking source for each server based on how the upstream project releases:

| Source type        | When to use                                                          | nvfetcher config                                   |
| ------------------ | -------------------------------------------------------------------- | -------------------------------------------------- |
| Flake input        | Upstream is a Nix flake                                              | Add to `flake.nix` inputs, track main              |
| GitHub main/master | No releases, or releases lag significantly behind active development | `src.git` + `src.use_commit = true` + `src.branch` |
| GitHub releases    | Upstream tags releases regularly                                     | `src.github` (tracks latest tag)                   |
| PyPI / npm latest  | Upstream publishes releases to the registry promptly                 | `src.pypi` or `src.cmd` with registry URL          |

Consumers pin versions via their own `flake.lock`. Per-package version overrides are always possible through the overlay system.

### Update App (`nix run .#update`)

Defined in `apps/update.nix` wrapping `apps/update.sh` via `writeShellApplication` with all runtime dependencies. Runs 6 steps: (1) `nix flake update`, (2) `nvfetcher` to refresh versions, (3) regenerate npm lock files, (4) update `npmDepsHash` values via `prefetch-npm-deps`, (5) update Go `vendorHash`, (6) verify with `nix flake show`.

### mkMcpWrapper

`overlays/mk-mcp-wrapper.nix` exports a function `{ name, pkg, modes }` where `modes = { stdio = "cmd" or null; http = "cmd" or null; }` (at least one must be non-null). It produces a `writeShellApplication` that dispatches `--stdio`/`--http` flags to the underlying binary. All exported packages go through this wrapper.

### Package Build Patterns

Every package follows a two-layer pattern: build an `unwrapped` derivation, then wrap it with `mkMcpWrapper`.

<!-- dprint-ignore -->
| Pattern        | Used for                                                             | Builder                                                         |
| -------------- | -------------------------------------------------------------------- | --------------------------------------------------------------- |
| External flake | nixos-mcp                                                            | Consumed from `mcp-nixos` flake input                           |
| npm            | context7-mcp, git-intel-mcp                                          | `buildNpmPackage` with tracked lock file from `overlays/locks/` |
| Script         | effect-mcp                                                           | `stdenv.mkDerivation` or `writeShellApplication`                |
| Python         | fetch-mcp, git-mcp, kagi-mcp                                         | `python313Packages.buildPythonApplication` with pyproject       |
| Go             | github-mcp                                                           | `buildGoModule` with vendorHash                                 |

### Server Reference

<!-- dprint-ignore -->
| Package   | Upstream                                       | Track      | Builder              | Transport   | Scope  | Tool Discovery |
| --------- | ---------------------------------------------- | ---------- | -------------------- | ----------- | ------ | -------------- |
| nixos-mcp | [flake](https://github.com/utensils/mcp-nixos) | flake main | external flake input | stdio, http | remote | runtime        |

| context7-mcp | [npm](https://www.npmjs.com/package/@upstash/context7-mcp) | npm latest | `buildNpmPackage` | stdio, http | remote | runtime |

| effect-mcp | [npm](https://www.npmjs.com/package/effect-mcp) | npm latest | `stdenv.mkDerivation` | stdio | remote | [source](https://github.com/tim-smart/effect-mcp) |

| fetch-mcp | [PyPI](https://pypi.org/project/mcp-server-fetch/) | PyPI latest | `buildPythonApplication` (3.13) | stdio | remote | runtime |

| git-intel-mcp | [GitHub](https://github.com/hoangsonww/GitIntel-MCP-Server) | master HEAD | `buildNpmPackage` | stdio | local | runtime |

| git-mcp | [PyPI](https://pypi.org/project/mcp-server-git/) | PyPI latest | `buildPythonApplication` (3.13) | stdio | local | runtime |

| github-mcp | [GitHub](https://github.com/github/github-mcp-server) | tagged releases | `buildGoModule` | stdio, http | remote | [README](https://github.com/github/github-mcp-server) |

| kagi-mcp | [PyPI](https://pypi.org/project/kagimcp/) | PyPI latest | `buildPythonApplication` (3.14) | stdio, http | remote | [source](https://github.com/kagisearch/kagi-mcp) |

### Updating Tool Lists

Tool names are stored in `meta.tools` in each server module (`modules/servers/<name>.nix`). To update:

**Runtime discovery** (servers marked `runtime`): start the server and query `tools/list` via MCP protocol. No auth needed for these:

```bash
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0.1"}}}\n{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}\n' \
  | timeout 10 nix run .#<package> -- --stdio 2>/dev/null \
  | grep -o '"name":"[^"]*"'
```

**Manual lookup** (servers marked with source/README links): these require auth to start, so tool names must be verified from upstream source code or documentation. Follow the link in the Tool Discovery column.

## Naming Conventions

- Package overlay files: `overlays/<package-name>.nix` (e.g., `context7-mcp.nix`)
- Lock files: `overlays/locks/<package-name>-package-lock.json`
- Unwrapped derivations: `<name>-unwrapped` (internal, not exported from flake)
- Exported packages: lowercase with hyphens (e.g., `context7-mcp`, `git-intel-mcp`)
- nvfetcher keys in `nvfetcher.toml` must match the exported package name

## Adding a New MCP Server

1. Determine upstream version strategy per the Upstream Version Strategy table (flake input, GitHub main/releases, PyPI/npm latest)
2. Add source entry to `nvfetcher.toml` (key must match the exported package name) — or for flake-based servers, add to `flake.nix` inputs
3. Run `nvfetcher` to regenerate `overlays/.nvfetcher/generated.nix` and `generated.json`
4. Create `overlays/<name>.nix` — access sources via `final.nv-sources.<key>`, build unwrapped, wrap with `mkMcpWrapper` (pass `version`, specify `stdio` and optionally `http` modes)
5. Add overlay to the list in `overlays/default.nix` (alphabetical)
6. Add per-package overlay export in `flake.nix` (`overlays.<name>`, alphabetical)
7. Add package to `packages` inherit list in `flake.nix` (alphabetical)
8. Create `modules/servers/<name>.nix` with `meta` (`modes`, `scope`, `defaultPort`, `tools`), `settingsOptions`, `settingsToEnv`, `settingsToArgs`
9. Register the server module in `modules/home-manager.nix` (`serverFiles` attrset, alphabetical)
10. For npm packages: generate lock file in `overlays/locks/`, add `npmDepsHash` to `overlays/hashes.json`, add lock regen + hash prefetch calls to `apps/update.sh`
11. For Go packages: add `vendorHash` to `overlays/hashes.json`, add vendor hash update call to `apps/update.sh`
12. Add row to README.md Available Servers table (alphabetical)
13. Add row to CLAUDE.md Server Reference table (alphabetical)
14. Add package to CI build matrix in `.github/workflows/ci.yml` (alphabetical)
15. If server requires auth to start: add env var to `.github/workflows/update.yml` and document the required secret
16. Run `nix flake check` to verify linting and evaluation

## Code Quality

### Alphabetical Ordering

Keep entries sorted alphabetically in lists, attribute sets, JSON objects, markdown tables, and similar collections. This produces cleaner diffs when entries are added or removed.

### DRY Principle

Never duplicate logic, configuration, or patterns. When the same thing appears twice, extract it. Prefer functional patterns — composition, parameterization, and higher-order abstractions over copy-paste with modifications.

Current tech stack examples (update when new stacks are added):

- **Nix:** repeated attribute patterns → shared function or `let` binding. Common overlay/module patterns → parameterized helper (e.g., `mkMcpWrapper`).
- **Bash:** repeated command sequences → function within the script, or a shared library script for cross-script reuse.
- **Config/flags:** linter invocations, tool flags, etc. must be defined in one place and consumed by all callers. When adding or changing, update the single source of truth — not each consumer independently.

### Nix

All Home Manager module options must use explicit NixOS module types (`types.str`, `types.enum`, `types.nullOr`, `types.port`, etc.) to produce clear evaluation-time errors. Never use `types.anything` or untyped values where a specific type is known. Overlay functions accessing nvfetcher sources must go through `final.nv-sources.<key>` — never import `generated.nix` directly. Computed hashes (`npmDepsHash`, `vendorHash`) belong in the `overlays/hashes.json` sidecar, not inline in overlay files.

### Bash

All shell scripts (including generated wrappers) must use strict mode:

```bash
#!/usr/bin/env bash
set -euETo pipefail
shopt -s inherit_errexit 2>/dev/null || :
```

### Linting

All code must pass the project linters before committing. Run from the devShell:

- **Nix:** `alejandra` (formatting), `deadnix` (dead code), `statix` (anti-patterns)
- **Shell:** `shellcheck`, `shellharden`, `shfmt`
- **Markdown/TOML/JSON:** `dprint`

## Home Manager Module

Servers are configured under `services.mcp-servers.servers.<name>` with options: `enable`, `package`, `transport` (stdio/http), `port`, `host`, `settings`, `env`, `args`, `environmentFiles`. Servers marked `local` in the module are stdio-only. Remote/HTTP servers get systemd user services.

Secrets must use `environmentFiles` (list of paths to `KEY=VALUE` files read at runtime), not `settings` or `env` which end up in the Nix store. For stdio servers, `environmentFiles` generates a wrapper script that sources the files before exec. For HTTP servers, the files are passed to systemd `EnvironmentFile`.

### `settingsToEnv` / `settingsToArgs` Contract

Every environment variable or CLI flag an upstream server reads should be lifted into a typed NixOS option in `settingsOptions`. `settingsToEnv` and `settingsToArgs` bridge typed options back to the format the server expects. Users never write raw env var names — they set typed options.

### General vs Server-Specific Options

`port`, `host`, `transport` are general options shared across all servers. Server-specific configuration (e.g., `path` for nixos-mcp's HTTP mount point) goes in `settingsOptions`. If an upstream env var maps directly to a general option, `settingsToEnv` reads the general option — no duplicate in `settingsOptions`.

### Drift Detection Scope

Drift detection should cover both tools AND config options. When upstream adds a new env var, drift should flag it so we can lift it into a typed option.
