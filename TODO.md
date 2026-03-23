# TODO

## Pre-publish

- [ ] Final review: walk through every commit from first to last
- [ ] Distribute tip changes into stack commits — tip has overlay refactor, credentials system, Python 3.14 migration, settings.json permissions, README/CLAUDE.md updates that need to go into their respective commits
- [ ] Investigate mcp-proxy single-session limitation — mcp-proxy bridges a single stdio process, so only one MCP client session at a time. Affects all bridge servers (effect-mcp, fetch-mcp, git-intel-mcp, openmemory-mcp, sequential-thinking-mcp, sympy-mcp). For now these are HTTP systemd services (shared), which works if only one client connects. Multi-session needs native HTTP or auth proxy.
- [ ] github-mcp transport decision: currently stdio (per-session) because mcp-proxy bridge is single-session and native HTTP requires client-side auth headers. Consider switching to native HTTP if auth proxy or per-client header support is implemented.
- [ ] Bug: Claude Code doesn't handle `tools/list_changed` notifications — dynamic toolsets don't work. Defaulted `dynamicToolsets` to `false` as workaround. File upstream bug if not already known.
- [x] Bug: git-intel-mcp `meta.mainProgram` warning — fixed with `meta.mainProgram = "git-intel-mcp"` in overlay
- [ ] openmemory-mcp full redesign before installing. See memory `project_openmemory_design.md` (design notes) and `project_openmemory_research.md` (research findings with viable/dismissed paths):
  - **Research complete.** 60+ env vars documented, all backends mapped, embedding providers compared.
  - Use `types.attrTag` for backend config (sqlite vs postgres discriminated union, available since nixpkgs 24.05)
  - Embeddings: default to ollama + nomic-embed-text (768 dims, free, offline, ~5% quality gap vs commercial)
  - Ollama models: NixOS built-in `services.ollama.loadModels` + `syncModels = true` (declarative, runtime pull)
  - Shared Postgres: NixOS cooperative merging pattern (`ensureDatabases` + `ensureUsers` + `extensions`)
  - ~~Fix transport: openmemory has native HTTP MCP on `POST /mcp` — current `http = "bridge"` is wrong~~ DONE
  - Don't install until module is redesigned with above patterns
- [ ] Refactor credentials to use `types.attrTag` instead of assertions:
  - Current: `credentials = { file = nullOr str; helper = nullOr str; }` with assertion for mutual exclusion
  - Better: `credentials = types.attrTag { file = types.str; helper = types.str; }` — type-enforced exactly-one
  - Usage becomes `settings.credentials.file = "/path";` OR `settings.credentials.helper = "/path";` (same API)
  - Removes need for the mutual exclusion assertion entirely
  - Review other places where assertions enforce "pick one" that could use `attrTag` instead
- [ ] Audit nvfetcher sources for provenance — prefer official GitHub repos over PyPI/npm when the publisher is unclear. Specifically: `kagimcp` and `kagiapi` are fetched from PyPI but the official source is `github.com/kagisearch/kagimcp`. Consider switching to GitHub releases or tags for better provenance. Review all sources for similar concerns.
- [ ] Add `check-health` integration test script — starts each server and verifies it responds on its configured port. See memory `project_health_check.md` for design notes and bug history that motivated this.

## Publish

- [x] Create GitHub repo
- [x] Push stack to remote (PRs 1-8 merged, remaining commits in review)
- [x] Configure GitHub repo secrets: `CACHIX_AUTH_TOKEN`
- [ ] Configure GitHub repo secrets: `MCP_GITHUB_TOKEN`, `MCP_KAGI_API_KEY`, `MCP_OPENMEMORY_API_KEY`
- [ ] Create `automated` and `drift` issue labels
- [ ] README: add CI status badge
- [x] Verify CI workflow runs on first push
- [ ] Verify Copilot Coding Agent picks up drift issues (set Claude as model in Copilot settings)

## Post-publish

- [ ] Wire remaining credential servers into nixos-config:
  - kagi-mcp: needs `KAGI_API_KEY` sops secret + `mkStdioEntry` or HM enable with credentials
  - context7-mcp: needs `CONTEXT7_API_KEY` sops secret
  - openmemory-mcp: needs `OM_API_KEY` + `OPENAI_API_KEY` sops secrets
  - aws-mcp: HTTP-only external, manual config `{ url = "https://knowledge-mcp.global.api.aws"; type = "http"; }`
- [ ] Ecosystem mapper design + drop normalized wrappers. See memory `project_normalized_redesign.md` for full context.
  - Normalized wrappers (`pkgs.nix-mcp-servers.normalized.*`) are out of sync with HM/lib — missing env vars (kagi FASTMCP_*), bridge flags (--pass-environment), path routing (/mcp), credential injection. Known incomplete, nobody consuming yet.
  - Replace with ecosystem mappers: server module `meta.modes` + `settingsToEnv`/`settingsToArgs` is the single source of truth. Mappers generate correct configs for each target ecosystem.
  - Target ecosystems: Claude Code (primary), Kiro CLI, Copilot. Users can plug in custom mappers.
  - Kiro/Copilot implementations should USE the mapper API to validate it works (test cases, not special cases).
  - Config methods to validate: global HM install, per-project mkStdioEntry, each ecosystem output.
  - When mappers exist, remove `normalized` attrset and `mk-mcp-wrapper.nix`.
- [ ] Per-client mcpConfig for native HTTP auth (future, if needed):
  - github-mcp native HTTP requires client-side `Authorization: Bearer` header
  - Claude Code: `headersHelper` (script path) — works
  - Kiro CLI: `headers` with `${env:VAR_NAME}` interpolation — needs env wrapping or auth proxy
  - Auth proxy option: Caddy reverse proxy reads sops, injects header. Any client connects without auth.
  - Decision deferred until multi-session bridge or native HTTP is needed
- [ ] Add new servers (one commit each, stacked):
  - filesystem-mcp — `@modelcontextprotocol/server-filesystem` (npm, `buildNpmPackage`)
  - atlassian-mcp — `mcp-atlassian` (PyPI, `buildPythonApplication`, Jira + Confluence Data Center via PAT)
  - gitlab-mcp — `@zereight/mcp-gitlab` (npm, `buildNpmPackage`, 100+ tools, self-hosted via `GITLAB_API_URL`)
  - slack-mcp — remote-only HM module (`mcp.slack.com`, Streamable HTTP, no local binary)

## Done

- [x] Add LICENSE file (Unlicense)
- [x] Lint: pass all linters and fix issues _(rule codified in CLAUDE.md — Code Quality)_
- [x] Bash strict mode _(rule codified in CLAUDE.md — Code Quality > Bash)_
- [x] Refactor nvfetcher integration to idiomatic pattern _(rule codified in CLAUDE.md — Code Quality > Nix)_
- [x] README: Home Manager and per-package overlay usage examples
- [x] flake.nix: export per-package overlays
- [x] kagi-mcp: bumped from python312 to python314
- [x] nvfetcher.toml: rename sequential-thinking key _(rule codified in CLAUDE.md — Naming Conventions)_
- [x] Validate all packages build: all 12 pass `nix build`
- [x] DRY linting: unified flags between flake checks and post-write hook _(rule codified in CLAUDE.md — Code Quality > DRY)_
- [x] Add `nix flake check` evaluation tests (formatting, deadnix, statix, shellcheck, shellharden)
- [x] Home Manager module: standalone eval check in flake checks
- [x] mkMcpWrapper: `--version` flag
- [x] lib.mkMcpConfig usage example in README
- [x] MCP tool auto-approval research: Claude Code supports `permissions.allow` with `mcp__<server>__<tool>` matchers
- [x] Tool permissions: `meta.tools` in server modules, `config.services.mcp-servers.tools` output, `lib.mapTools`
- [x] Auth/secrets: `credentials` system — `mkCredentialsOption` with `file`/`helper`, runtime env var injection for systemd and stdio wrappers
- [x] Overlay namespace refactor: `pkgs.nix-mcp-servers.*` (raw) + `pkgs.nix-mcp-servers.normalized.*` (wrapper). Removed per-package overlays.
- [x] Overlay packages are raw binaries — mkMcpWrapper moved to normalized sub-attrset only
- [x] mkStdioEntry: derives server name from `package.pname`/`passthru.mcpName`, no `name` arg needed
- [x] All Python packages use Python 3.14 (prevents version pollution when multiple Python MCP servers in PATH)
- [x] meta.mainProgram set on packages where binary name differs from pname (git-mcp, fetch-mcp, github-mcp, kagi-mcp)
- [x] github-mcp: mcp-proxy bridge was single-session — switched to per-session stdio with credentials baked in via mkStdioEntry
- [x] HM systemd services use writeShellApplication with runtimeInputs for isolated PATH
- [x] mcp-proxy: `--pass-environment` flag required to forward env vars to child process
- [x] Bridge servers append `/mcp` to URL (mcp-proxy default endpoint)
- [x] settings.json: all MCP servers have wildcard allow entries for tool permissions
- [x] Nixos-config integration: 8 MCPs working — 5 HTTP (systemd), 3 stdio (per-session: github-mcp, git-mcp, git-intel-mcp)
- [x] Drift detection script: `nix run .#check-drift` — queries `tools/list` via MCP protocol, diffs against `meta.tools`
- [x] GitHub Actions CI: `nix flake check` + build matrix for all packages (`.github/workflows/ci.yml`)
- [x] GitHub Actions: nightly update workflow with auto-PR (`.github/workflows/update.yml`)
- [x] GitHub Actions: weekly drift detection with auto-issue for Copilot (`.github/workflows/check-drift.yml`)
- [x] Add README examples for tool permissions: Claude Code `permissions.allow`, generic JSON export, CLI flag generation
- [x] Check upstream for HTTP mode: kagi-mcp now supports `--http` (updated overlay + module). effect-mcp, fetch-mcp, openmemory-mcp, sequential-thinking-mcp remain stdio-only.
- [x] Distribute tip commit changes into earlier stack commits — all content now lives in the commit that introduces the feature it documents
- [x] Cachix binary cache (`hof-nix-mcp-servers`) — replaces magic-nix-cache, content-addressed dedup
- [x] Dependabot for GitHub Actions version bumps
- [x] Refactored update workflow: single job, `peter-evans/create-pull-request`, dry-run on branches, verify step
