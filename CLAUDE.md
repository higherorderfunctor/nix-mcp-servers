# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

nix-mcp-servers is a Nix flake that packages Model Context Protocol (MCP) servers as Nix derivations with a unified CLI interface.

## Build & Validation Commands

```bash
nix flake show                # List all outputs (quick validation)
nix develop                   # Enter devShell with all packages available
nix run .#update              # Full update pipeline: flake inputs, nvfetcher, locks, hashes
nix fmt                       # Format all Nix files with alejandra
```

## Architecture

### Flake Structure

- **flake.nix** — Defines inputs, composes the overlay, exports packages and devShell.
- **overlays/default.nix** — Composes all per-package overlays via `lib.composeManyExtensions`.
- **overlays/sources.nix** — Overlay that exposes `final.nv-sources.<name>` from nvfetcher's `generated.nix` merged with `hashes.json`.
- **overlays/mk-mcp-wrapper.nix** — Shared wrapper that gives every server a uniform `--stdio` / `--http` CLI.

### mkMcpWrapper

`overlays/mk-mcp-wrapper.nix` exports a function `{ name, pkg, modes }` where `modes = { stdio = "cmd" or null; http = "cmd" or null; }` (at least one must be non-null). It produces a `writeShellApplication` that dispatches `--stdio`/`--http` flags to the underlying binary. All exported packages go through this wrapper.

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

Overlay functions accessing nvfetcher sources must go through `final.nv-sources.<key>` — never import `generated.nix` directly. Computed hashes (`npmDepsHash`, `vendorHash`) belong in the `overlays/hashes.json` sidecar, not inline in overlay files.

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

- **nvfetcher.toml** — Defines upstream sources (PyPI, npm registry, GitHub) for each package.
- **overlays/.nvfetcher/generated.nix** — Auto-generated Nix expressions with fetchers (managed by `nvfetcher`, do not edit).
- **overlays/.nvfetcher/generated.json** — Raw JSON metadata (managed by `nvfetcher`, do not edit).
- **overlays/sources.nix** — Overlay that calls `generated.nix` with fetchers and merges sidecar hashes, exposing `final.nv-sources.<name>`.
- **overlays/hashes.json** — Sidecar file for computed hashes (`npmDepsHash`, `vendorHash`) managed by the update script.

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
