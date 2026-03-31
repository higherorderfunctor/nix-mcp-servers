# TODO

## Dev work

- [ ] Refactor credentials to use `types.attrTag` instead of assertions. See memory `project_credentials_attrtag.md`. **Needs HITL**.
- [ ] Ecosystem mapper design: generate configs per target ecosystem from server module `meta.modes` + `settingsToEnv`/`settingsToArgs`. Target ecosystems: Claude Code (primary), Kiro CLI, Copilot.

## GitHub repo

- [ ] Create `automated` and `drift` issue labels
- [ ] README: add CI status badge
- [ ] Verify Copilot Coding Agent picks up drift issues (set Claude as model in Copilot settings)

## Future MCPs

### openmemory-mcp

Full redesign before installing. See memory `project_openmemory_design.md` and `project_openmemory_research.md`:

- [ ] Use `types.attrTag` for backend config (sqlite vs postgres discriminated union)
- [ ] Embeddings: default to ollama + nomic-embed-text (768 dims, free, offline)
- [ ] Ollama models: NixOS `services.ollama.loadModels` + `syncModels = true`
- [ ] Shared Postgres: NixOS cooperative merging pattern (`ensureDatabases` + `ensureUsers` + `extensions`)

### cclsp

LSP-MCP bridge with eslint adapter. See memory `project_cclsp_eslint_adapter.md`:

1. [ ] Test eslint adapter patch against charter-developer-platform
2. [ ] Package cclsp in nix-mcp-servers (`buildNpmPackage` + patch)
3. [ ] Add `modules/servers/cclsp.nix` + HM integration
4. [ ] Upstream eslint adapter PR to `ktnyt/cclsp`

### filesystem-mcp

- [ ] `@modelcontextprotocol/server-filesystem` (npm, `buildNpmPackage`)

### atlassian-mcp

- [ ] `mcp-atlassian` (PyPI, `buildPythonApplication`, Jira + Confluence Data Center via PAT)

### gitlab-mcp

- [ ] `@zereight/mcp-gitlab` (npm, `buildNpmPackage`, 100+ tools, self-hosted via `GITLAB_API_URL`)

### slack-mcp

- [ ] Remote-only HM module (`mcp.slack.com`, Streamable HTTP, no local binary)
