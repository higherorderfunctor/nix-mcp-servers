{inputs, ...}: final: _: let
  mkMcpWrapper = final.callPackage ./mk-mcp-wrapper.nix {};
  unwrapped = inputs.mcp-nixos.packages.${final.stdenv.hostPlatform.system}.default;
in {
  nixos-mcp = mkMcpWrapper {
    name = "nixos-mcp";
    version = unwrapped.version or "unknown";
    pkg = unwrapped;
    modes = {
      stdio = "mcp-nixos";
      http = "env MCP_NIXOS_TRANSPORT=http mcp-nixos";
    };
  };
}
