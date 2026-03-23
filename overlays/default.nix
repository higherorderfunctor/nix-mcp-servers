{inputs, ...}: final: prev: let
  # ── Sources ──────────────────────────────────────────────────────────
  # Merge nvfetcher generated sources with sidecar hashes
  sourcesOverlay = import ./sources.nix {} final prev;

  # Make nv-sources available for package files
  nv-sources = sourcesOverlay.nv-sources;

  # ── Package builder ──────────────────────────────────────────────────
  # Each file is a plain function: final -> derivation
  # Files that need flake inputs use the { inputs, ... }: final: pattern
  callPkg = path: let
    fn = import path;
    args = builtins.functionArgs fn;
  in
    if args ? inputs
    then fn {inherit inputs;} (final // {inherit nv-sources;})
    else fn (final // {inherit nv-sources;});

  # ── Raw packages ─────────────────────────────────────────────────────
  context7-mcp = callPkg ./context7-mcp.nix;
  effect-mcp = callPkg ./effect-mcp.nix;
  fetch-mcp = callPkg ./fetch-mcp.nix;
  git-intel-mcp = callPkg ./git-intel-mcp.nix;
  git-mcp = callPkg ./git-mcp.nix;
  github-mcp = callPkg ./github-mcp.nix;
  kagi-mcp = callPkg ./kagi-mcp.nix;
  mcp-proxy = callPkg ./mcp-proxy.nix;
  nixos-mcp = callPkg ./nixos-mcp.nix;
  openmemory-mcp = callPkg ./openmemory-mcp.nix;
  sequential-thinking-mcp = callPkg ./sequential-thinking-mcp.nix;
  sympy-mcp = callPkg ./sympy-mcp.nix;

  # ── Normalized wrapper ───────────────────────────────────────────────
  mkMcpWrapper = final.callPackage ./mk-mcp-wrapper.nix {};

  mkNormalized = {
    name,
    pkg,
    version ? pkg.version or "unknown",
    modes,
  }:
    mkMcpWrapper {inherit name version pkg modes;};

  proxyCmd = cmd: "${mcp-proxy}/bin/mcp-proxy --pass-environment --port \"$MCP_PORT\" -- ${cmd}";
in {
  inherit nv-sources;

  nix-mcp-servers = {
    # Raw packages — upstream binaries as-is
    inherit
      context7-mcp
      effect-mcp
      fetch-mcp
      git-intel-mcp
      git-mcp
      github-mcp
      kagi-mcp
      mcp-proxy
      nixos-mcp
      openmemory-mcp
      sequential-thinking-mcp
      sympy-mcp
      ;

    # Normalized — mkMcpWrapper with --stdio/--http/--version dispatch
    normalized = {
      context7-mcp = mkNormalized {
        name = "context7-mcp";
        pkg = context7-mcp;
        modes = {
          stdio = "context7-mcp --transport stdio";
          http = "context7-mcp --transport http";
        };
      };
      effect-mcp = mkNormalized {
        name = "effect-mcp";
        pkg = effect-mcp;
        modes = {
          stdio = "effect-mcp";
          http = proxyCmd "effect-mcp";
        };
      };
      fetch-mcp = mkNormalized {
        name = "fetch-mcp";
        pkg = fetch-mcp;
        modes = {
          stdio = "mcp-server-fetch";
          http = proxyCmd "mcp-server-fetch";
        };
      };
      git-intel-mcp = mkNormalized {
        name = "git-intel-mcp";
        pkg = git-intel-mcp;
        modes = {
          stdio = "git-intel-mcp";
          http = proxyCmd "git-intel-mcp";
        };
      };
      git-mcp = mkNormalized {
        name = "git-mcp";
        pkg = git-mcp;
        modes = {
          stdio = "mcp-server-git";
          http = proxyCmd "mcp-server-git";
        };
      };
      github-mcp = mkNormalized {
        name = "github-mcp";
        pkg = github-mcp;
        modes = {
          stdio = "github-mcp-server stdio";
          http = proxyCmd "github-mcp-server stdio";
        };
      };
      kagi-mcp = mkNormalized {
        name = "kagi-mcp";
        pkg = kagi-mcp;
        modes = {
          stdio = "kagimcp";
          http = "kagimcp --http";
        };
      };
      nixos-mcp = mkNormalized {
        name = "nixos-mcp";
        pkg = nixos-mcp;
        version = nixos-mcp.version or "unknown";
        modes = {
          stdio = "mcp-nixos";
          http = "env MCP_NIXOS_TRANSPORT=http mcp-nixos";
        };
      };
      openmemory-mcp = mkNormalized {
        name = "openmemory-mcp";
        pkg = openmemory-mcp;
        modes = {
          stdio = "openmemory-mcp";
          http = proxyCmd "openmemory-mcp";
        };
      };
      sequential-thinking-mcp = mkNormalized {
        name = "sequential-thinking-mcp";
        pkg = sequential-thinking-mcp;
        modes = {
          stdio = "sequential-thinking-mcp";
          http = proxyCmd "sequential-thinking-mcp";
        };
      };
      sympy-mcp = mkNormalized {
        name = "sympy-mcp";
        pkg = sympy-mcp;
        modes = {
          stdio = "sympy-mcp";
          http = proxyCmd "sympy-mcp";
        };
      };
    };
  };
}
