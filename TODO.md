# TODO

## Dev work

- [ ] Auto-generate Claude Code MCP config + tool approvals from HM module. Currently `nixos-config/.../claude/default.nix` manually lists mcpServers and `permissions.allow` entries. Two improvements:
  - **Tool approvals**: replace manual `mcp__plugin_...__*` list with `lib.mapTools (server: _: "mcp__plugin_claude-code-home-manager_${server}__*") config.services.mcp-servers.tools` — auto-approves all tools from enabled servers.
  - **mcpServers**: HTTP servers already come from `config.services.mcp-servers.mcpConfig.mcpServers`. Stdio servers (git-mcp, git-intel-mcp, github-mcp, kagi-mcp) are manual `mkStdioEntry` calls because they need per-session creds. Consider adding a `stdioConfig` output to the HM module so `programs.claude-code.mcpServers` can be fully auto-generated. Or at minimum, a helper that merges HTTP mcpConfig + stdio entries.
  - See `nixos-config/home/caubut/features/cli/code/ai/claude/default.nix` lines 26-49 (mcpServers) and 89-98 (permissions.allow).
- [ ] HM ollama module in nixos-config: `modules/home-manager/ollama.nix` with `models` list + `nixglhost.enable`. See memory `project_openmemory_nixosconfig_migration.md` for full prompt and migration steps.

## GitHub repo

- [ ] Create `automated` and `drift` issue labels
- [ ] README: add CI status badge
- [ ] Verify Copilot Coding Agent picks up drift issues (set Claude as model in Copilot settings)

## Future MCPs

### openmemory-mcp

Full settings module done (60+ env vars, attrTag backends). See memory `project_openmemory_design.md` and `project_openmemory_research.md`.

- [ ] Wire into nixos-config: replace raw env vars in kiro config with typed options via `mkStdioEntry`
- [ ] README examples for common setups:
  - sqlite + synthetic (zero-dep default)
  - sqlite + ollama (local embeddings, no postgres)
  - postgres + ollama (production, shared DB)
  - NixOS: `services.ollama.loadModels` + `services.postgresql.ensureDatabases` patterns
  - HM-only: user service + activation script patterns for ollama/postgres

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
