# TODO

## Dev work

- [ ] Bug: Claude Code doesn't handle `tools/list_changed` notifications — dynamic toolsets don't work. Defaulted `dynamicToolsets` to `false` as workaround. File upstream bug if not already known.
- [ ] Investigate mcp-proxy single-session limitation — mcp-proxy bridges a single stdio process, so only one MCP client session at a time. Affects all bridge servers (effect-mcp, fetch-mcp, git-intel-mcp, openmemory-mcp, sequential-thinking-mcp, sympy-mcp). For now these are HTTP systemd services (shared), which works if only one client connects. Multi-session needs native HTTP or auth proxy.
- [ ] github-mcp transport decision: currently stdio (per-session) because mcp-proxy bridge is single-session and native HTTP requires client-side auth headers. Consider switching to native HTTP if auth proxy or per-client header support is implemented.
- [ ] Refactor credentials to use `types.attrTag` instead of assertions:
  - Current: `credentials = { file = nullOr str; helper = nullOr str; }` with assertion for mutual exclusion
  - Better: `credentials = types.attrTag { file = types.str; helper = types.str; }` — type-enforced exactly-one
  - Usage becomes `settings.credentials.file = "/path";` OR `settings.credentials.helper = "/path";` (same API)
  - Removes need for the mutual exclusion assertion entirely
  - Review other places where assertions enforce "pick one" that could use `attrTag` instead
- [ ] Audit nvfetcher sources for provenance — prefer official GitHub repos over PyPI/npm when the publisher is unclear. Specifically: `kagimcp` and `kagiapi` are fetched from PyPI but the official source is `github.com/kagisearch/kagimcp`. Consider switching to GitHub releases or tags for better provenance. Review all sources for similar concerns.
- [ ] Add `check-health` integration test script — starts each server and verifies it responds on its configured port. See memory `project_health_check.md` for design notes and bug history that motivated this.
- [ ] openmemory-mcp full redesign before installing. See memory `project_openmemory_design.md` and `project_openmemory_research.md`:
  - **Research complete.** 60+ env vars documented, all backends mapped, embedding providers compared.
  - Use `types.attrTag` for backend config (sqlite vs postgres discriminated union, available since nixpkgs 24.05)
  - Embeddings: default to ollama + nomic-embed-text (768 dims, free, offline, ~5% quality gap vs commercial)
  - Ollama models: NixOS built-in `services.ollama.loadModels` + `syncModels = true` (declarative, runtime pull)
  - Shared Postgres: NixOS cooperative merging pattern (`ensureDatabases` + `ensureUsers` + `extensions`)
  - Don't install until module is redesigned with above patterns

## Publish

- [ ] Configure GitHub repo secrets: `MCP_GITHUB_TOKEN`, `MCP_KAGI_API_KEY`, `MCP_OPENMEMORY_API_KEY`
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
