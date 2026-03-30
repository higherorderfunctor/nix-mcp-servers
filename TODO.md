# TODO

## Dev work

- [x] Bug: Claude Code doesn't handle `tools/list_changed` notifications — tracked upstream as anthropics/claude-code#41123 (open, 2026-03-30). Workaround: `dynamicToolsets` defaults to `false`. See memory `project_tools_list_changed_bug.md`.
- [ ] Investigate mcp-proxy single-session limitation — mcp-proxy bridges a single stdio process, so only one MCP client session at a time. Affects all bridge servers (effect-mcp, fetch-mcp, git-intel-mcp, openmemory-mcp, sequential-thinking-mcp, sympy-mcp). For now these are HTTP systemd services (shared), which works if only one client connects. Multi-session needs native HTTP or auth proxy.
- [ ] github-mcp transport decision: currently stdio (per-session) because mcp-proxy bridge is single-session and native HTTP requires client-side auth headers. Consider switching to native HTTP if auth proxy or per-client header support is implemented.
- [ ] Refactor credentials to use `types.attrTag` instead of assertions. Full migration plan with code diffs and verification checklist in memory `project_credentials_attrtag.md`. **Needs HITL** — changes lib/default.nix and modules/home-manager.nix, API-compatible but error messages change.
- [x] Audit nvfetcher sources for provenance — **complete**. All publishers verified, provenance comments added to nvfetcher.toml. No source type changes needed (PyPI is the official channel for all current packages). See memory `project_nvfetcher_audit.md`.
- [x] Add `check-health` integration test script — `apps/check-health.sh` written, registered in `apps/default.nix`. Probes stdio servers with MCP initialize request, skips servers requiring credentials. Run via `nix run .#check-health`.
- [ ] openmemory-mcp full redesign before installing. See memory `project_openmemory_design.md` and `project_openmemory_research.md`:
  - **Research complete.** 60+ env vars documented, all backends mapped, embedding providers compared.
  - Use `types.attrTag` for backend config (sqlite vs postgres discriminated union, available since nixpkgs 24.05)
  - Embeddings: default to ollama + nomic-embed-text (768 dims, free, offline, ~5% quality gap vs commercial)
  - Ollama models: NixOS built-in `services.ollama.loadModels` + `syncModels = true` (declarative, runtime pull)
  - Shared Postgres: NixOS cooperative merging pattern (`ensureDatabases` + `ensureUsers` + `extensions`)
  - Don't install until module is redesigned with above patterns

## Publish

- [ ] Create `automated` and `drift` issue labels
- [ ] README: add CI status badge
- [ ] Verify Copilot Coding Agent picks up drift issues (set Claude as model in Copilot settings)

## Stack review and distribution

- [ ] Final review: walk through every commit from first to last
- [ ] Distribute tip changes into stack commits — tip has overlay refactor, credentials system, Python 3.14 migration, settings.json permissions, README/CLAUDE.md updates that need to go into their respective commits

## Deferred

- [ ] Add cclsp (LSP-MCP bridge) with eslint adapter. See memory `project_cclsp_eslint_adapter.md` for full research context, patch details, and candidate evaluation:
  1. Test eslint adapter patch against charter-developer-platform (real eslint config in `.kiro/settings/lsp.json`)
  2. Package cclsp in nix-mcp-servers (`buildNpmPackage` + `0001-feat-add-eslint-adapter-for-workspace-configuration.patch`)
  3. Add `modules/servers/cclsp.nix` + HM integration (local scope, stdio transport)
  4. Upstream eslint adapter PR to `ktnyt/cclsp` — no existing PRs or forks cover this (checked 2026-03-30)
  - Patch files in `overlays/patches/cclsp/` — adapter handles `workspace/configuration`, `eslint/confirmESLintExecution`, custom notifications
  - Motivation: Kiro CLI lacks `workspace/configuration` support (kirodotdev/Kiro#6174, #6040), cclsp MCP bypass is the only working path

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
