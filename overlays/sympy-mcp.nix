_: final: _: let
  nv = final.nv-sources.sympy-mcp;
  mkMcpWrapper = final.callPackage ./mk-mcp-wrapper.nix {};
  python =
    final.python313.withPackages (ps:
      with ps; [mcp typer python-dotenv sympy]);
  unwrapped = final.writeShellApplication {
    name = "sympy-mcp-unwrapped";
    runtimeInputs = [python];
    text = ''exec mcp run "${nv.src}/server.py" "$@"'';
  };
in {
  sympy-mcp = mkMcpWrapper {
    name = "sympy-mcp";
    inherit (nv) version;
    pkg = unwrapped;
    modes = {
      stdio = "sympy-mcp-unwrapped";
      http = "${final.mcp-proxy}/bin/mcp-proxy --port \"$MCP_PORT\" -- sympy-mcp-unwrapped";
    };
  };
}
