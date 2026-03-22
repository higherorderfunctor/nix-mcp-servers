_: final: _: let
  nv = final.nv-sources.mcp-server-fetch;
  mkMcpWrapper = final.callPackage ./mk-mcp-wrapper.nix {};
  unwrapped = final.python313Packages.buildPythonApplication {
    pname = "fetch-mcp-unwrapped";
    inherit (nv) version src;
    pyproject = true;
    build-system = with final.python313Packages; [hatchling];
    dependencies = with final.python313Packages; [
      httpx
      markdownify
      mcp
      protego
      pydantic
      readabilipy
      requests
    ];
    postPatch = ''
      substituteInPlace src/mcp_server_fetch/server.py \
        --replace-fail 'AsyncClient(proxies=' 'AsyncClient(proxy='
    '';
    pythonRelaxDeps = ["httpx"];
    doCheck = false;
  };
in {
  fetch-mcp = mkMcpWrapper {
    name = "fetch-mcp";
    inherit (nv) version;
    pkg = unwrapped;
    modes = {
      stdio = "mcp-server-fetch";
      http = "${final.mcp-proxy}/bin/mcp-proxy --port \"$MCP_PORT\" -- mcp-server-fetch";
    };
  };
}
