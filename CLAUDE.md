# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

nix-mcp-servers is a Nix flake that packages Model Context Protocol (MCP) servers as Nix derivations with a unified CLI interface.

## Build & Validation Commands

```bash
nix flake show                # List all outputs (quick validation)
nix develop                   # Enter devShell with all packages available
```

## Architecture

### Flake Structure

- **flake.nix** — Defines inputs, composes the overlay, exports packages and devShell.

## Code Quality

### Alphabetical Ordering

Keep entries sorted alphabetically in lists, attribute sets, JSON objects, markdown tables, and similar collections. This produces cleaner diffs when entries are added or removed.

### DRY Principle

Never duplicate logic, configuration, or patterns. When the same thing appears twice, extract it. Prefer functional patterns — composition, parameterization, and higher-order abstractions over copy-paste with modifications.

Current tech stack examples (update when new stacks are added):

- **Nix:** repeated attribute patterns → shared function or `let` binding. Common overlay/module patterns → parameterized helper.
- **Bash:** repeated command sequences → function within the script, or a shared library script for cross-script reuse.
- **Config/flags:** linter invocations, tool flags, etc. must be defined in one place and consumed by all callers. When adding or changing, update the single source of truth — not each consumer independently.

### Nix


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
- `docs: update CLAUDE.md with conventional commits guide`
