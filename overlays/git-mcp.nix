_: final: _: let
  nv = final.nv-sources.mcp-server-git;
  mkMcpWrapper = final.callPackage ./mk-mcp-wrapper.nix {};
  unwrapped = final.python313Packages.buildPythonApplication {
    pname = "git-mcp-unwrapped";
    inherit (nv) version src;
    pyproject = true;
    build-system = with final.python313Packages; [hatchling];
    dependencies = with final.python313Packages; [click gitpython mcp pydantic];
    doCheck = false;
  };
in {
  # local scope — no --http
  git-mcp = mkMcpWrapper {
    name = "git-mcp";
    inherit (nv) version;
    pkg = unwrapped;
    modes.stdio = "mcp-server-git";
  };
}
