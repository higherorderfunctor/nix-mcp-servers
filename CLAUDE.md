# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

nix-mcp-servers is a Nix flake that packages Model Context Protocol (MCP) servers as Nix derivations. It provides a namespaced overlay (`pkgs.nix-mcp-servers.*`), optional normalized wrappers (`pkgs.nix-mcp-servers.normalized.*`), and a Home Manager module for declarative configuration.

## Build & Validation Commands

```bash
nix flake show                # List all outputs (quick validation)
nix build .#<package-name>    # Build a specific package (e.g., .#context7-mcp)
nix flake check               # Full flake evaluation check (linters + eval, does NOT build packages)
nix develop                   # Enter devShell with all packages available
nix run .#update              # Full update pipeline: flake inputs, nvfetcher, locks, hashes
nix fmt                       # Format all Nix files with alejandra
```

**Important:** `nix flake check` only runs linters and evaluation tests — it does **not** build packages. After any change to overlays, package definitions, or dependencies, always run `nix build .#<package>` on affected packages to verify they actually build. For broad changes, build all packages.

After any change to server modules, lib, or the HM module: restart affected systemd services and verify they respond on their configured port. Build checks do not catch runtime failures (wrong port, missing CLI flags, env var issues).

CI runs `nix flake check` and a per-package build matrix on every PR and push to main.

When debugging or fixing issues, prefer the correct architectural fix over quick workarounds. If an upstream server supports a feature natively (e.g., HTTP transport), investigate how to use it properly instead of falling back to bridge/proxy. When unsure whether a fix is correct or a shortcut, ask the user before implementing. Quick hacks accumulate technical debt and mask the real integration requirements. Priority order: official native support > bridge/proxy > patch upstream code.

All packages from the overlay are available in the devShell (`nix develop`). Use the devShell to test changes interactively instead of digging through `/nix/store` paths. Reload with `direnv reload` or re-enter with `nix develop` after changes.

## Architecture

### Flake Structure

- **flake.nix** — Defines inputs, composes the overlay, exports packages, devShell, `lib`, and `homeManagerModules.default`.
- **lib/default.nix** — Core library: settings validation (`evalSettings`), entry builders (`mkStdioEntry`, `mkHttpEntry`, `mkStdioConfig`). Loads server definitions on demand via `loadServer` — no centralized server list. Works standalone without Home Manager.
- **overlays/default.nix** — Single overlay adding `pkgs.nix-mcp-servers` namespace (raw packages + `normalized` sub-attrset).
- **overlays/sources.nix** — Overlay that exposes `final.nv-sources.<name>` from nvfetcher's `generated.nix` merged with `hashes.json`.
- **modules/home-manager.nix** — Home Manager service layer: options, systemd services, assertions. Delegates entry building and settings validation to `lib/`.
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

Every package follows a two-layer pattern: the overlay builds a raw package, the HM module or lib wraps it for the target transport.

<!-- dprint-ignore -->
| Pattern        | Used for                                                             | Builder                                                         |
| -------------- | -------------------------------------------------------------------- | --------------------------------------------------------------- |
| External flake | nixos-mcp                                                            | Consumed from `mcp-nixos` flake input                           |
| npm            | context7-mcp, git-intel-mcp, openmemory-mcp, sequential-thinking-mcp | `buildNpmPackage` with tracked lock file from `overlays/locks/` |
| Script         | effect-mcp, sympy-mcp                                                | `stdenv.mkDerivation` or `writeShellApplication`                |
| Python         | fetch-mcp, git-mcp, kagi-mcp, mcp-proxy                              | `python314Packages.buildPythonApplication` with pyproject       |
| Go             | github-mcp                                                           | `buildGoModule` with vendorHash                                 |

### Server Reference

<!-- dprint-ignore -->
| Package | Upstream | Track | Builder | Transport | Scope | Tool Discovery |
| ------- | -------- | ----- | ------- | --------- | ----- | -------------- |
| context7-mcp | [npm](https://www.npmjs.com/package/@upstash/context7-mcp) | npm latest | `buildNpmPackage` | stdio, http (native) | remote | runtime |
| effect-mcp | [npm](https://www.npmjs.com/package/effect-mcp) | npm latest | `stdenv.mkDerivation` | stdio, http (bridge) | remote | [source](https://github.com/tim-smart/effect-mcp) |
| fetch-mcp | [PyPI](https://pypi.org/project/mcp-server-fetch/) | PyPI latest | `buildPythonApplication` (3.14) | stdio, http (bridge) | remote | runtime |
| git-intel-mcp | [GitHub](https://github.com/hoangsonww/GitIntel-MCP-Server) | master HEAD | `buildNpmPackage` | stdio | local | runtime |
| git-mcp | [PyPI](https://pypi.org/project/mcp-server-git/) | PyPI latest | `buildPythonApplication` (3.14) | stdio | local | runtime |
| github-mcp | [GitHub](https://github.com/github/github-mcp-server) | tagged releases | `buildGoModule` | stdio | remote | runtime |
| kagi-mcp | [PyPI](https://pypi.org/project/kagimcp/) | PyPI latest | `buildPythonApplication` (3.14) | stdio | remote | runtime |
| nixos-mcp | [flake](https://github.com/utensils/mcp-nixos) | flake main | external flake input | stdio, http (native) | remote | runtime |
| openmemory-mcp | [npm](https://www.npmjs.com/package/openmemory-js) | npm latest | `buildNpmPackage` | stdio, http (bridge) | remote | runtime |
| sequential-thinking-mcp | [npm](https://www.npmjs.com/package/@modelcontextprotocol/server-sequential-thinking) | npm latest | `buildNpmPackage` | stdio, http (bridge) | remote | runtime |
| sympy-mcp | [GitHub](https://github.com/sdiehl/sympy-mcp) | main HEAD | `writeShellApplication` | stdio, http (bridge) | remote | runtime |

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
6. Add package to `overlays/default.nix` raw + normalized sections (alphabetical)
7. Add package to `packages` inherit list in `flake.nix` (alphabetical)
8. Create `modules/servers/<name>.nix` with `meta` (`modes`, `scope`, `defaultPort`, `tools`), `settingsOptions`, `settingsToEnv`, `settingsToArgs`
9. Register the server module in `modules/home-manager.nix` (`serverFiles` attrset, alphabetical)
10. For npm packages: generate lock file in `overlays/locks/`, add `npmDepsHash` to `overlays/hashes.json`, add lock regen + hash prefetch calls to `apps/update.sh`
11. For Go packages: add `vendorHash` to `overlays/hashes.json`, add vendor hash update call to `apps/update.sh`
12. Add row to README.md Available Servers table (alphabetical)
13. Add row to CLAUDE.md Server Reference table (alphabetical)
14. Add package to CI build matrix in `.github/workflows/ci.yml` (alphabetical)
15. If server requires auth to start: add env var to `.github/workflows/update.yml` and document the required secret
16. Update `.claude/settings.json` — add `mcp__plugin_claude-code-home-manager_<name>__*` wildcard allow entry so MCP tools work without prompting
17. Run `nix flake check` to verify linting and evaluation

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

Enabling a server (`servers.<name>.enable = true`) creates a systemd HTTP service and an HTTP entry in `mcpConfig`. All packaged servers support HTTP (native or via mcp-proxy bridge).

Packaged servers have options: `enable`, `package`, `service.port`, `service.host`, `settings`, `env`, `args`. External HTTP-only servers (e.g., `aws-mcp`) are not part of the HM module — use `lib.externalServers` to get pre-baked config entries.

Secrets use the `credentials` system — servers that need auth declare `credentials` in `settingsOptions` via `mkCredentialsOption`. Users set `settings.credentials.file` (path to raw secret) or `settings.credentials.helper` (executable outputting the secret). Credentials are injected at runtime via systemd environment, never stored in the Nix store.

For stdio-only configs (devShells, non-HM systems), use `lib.mkStdioConfig` or `lib.mkStdioEntry` directly — these are standalone lib functions, not part of the HM module.

### `settingsToEnv` / `settingsToArgs` Contract

Signature: `settingsToEnv = cfg: mode:` and `settingsToArgs = cfg: mode:` where `mode` is `"stdio"` or `"http"`. The HM module always passes `"http"`. The `"stdio"` mode is used by `lib.mkStdioEntry` for standalone configs.

Every environment variable or CLI flag an upstream server reads should be lifted into a typed NixOS option in `settingsOptions`. `settingsToEnv` and `settingsToArgs` bridge typed options back to the format the server expects. Users never write raw env var names — they set typed options.

### General vs Server-Specific Options

`service.port`, `service.host` are general service options. Server-specific configuration (e.g., `path` for nixos-mcp's HTTP mount point) goes in `settingsOptions`. If an upstream env var maps directly to a general option, `settingsToEnv` reads the general option — no duplicate in `settingsOptions`.

### Drift Detection Scope

Drift detection should cover both tools AND config options. When upstream adds a new env var, drift should flag it so we can lift it into a typed option.
