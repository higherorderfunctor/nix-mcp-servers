_: final: _: let
  nv = final.nv-sources.mcp-proxy;
in {
  mcp-proxy = final.python313Packages.buildPythonApplication {
    pname = "mcp-proxy";
    inherit (nv) version src;
    pyproject = true;
    build-system = with final.python313Packages; [setuptools];
    dependencies = with final.python313Packages; [httpx-auth mcp uvicorn];
    doCheck = false;
  };
}
