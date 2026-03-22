_: final: _: let
  nv = final.nv-sources.kagimcp;
  nv_kagiapi = final.nv-sources.kagiapi;
  mkMcpWrapper = final.callPackage ./mk-mcp-wrapper.nix {};
  kagiapi = final.python314Packages.buildPythonPackage {
    pname = "kagiapi";
    inherit (nv_kagiapi) version src;
    pyproject = true;
    build-system = with final.python314Packages; [setuptools];
    dependencies = with final.python314Packages; [requests typing-extensions];
    doCheck = false;
  };
  unwrapped = final.python314Packages.buildPythonApplication {
    pname = "kagi-mcp-unwrapped";
    inherit (nv) version src;
    pyproject = true;
    build-system = with final.python314Packages; [hatchling];
    dependencies = with final.python314Packages; [kagiapi mcp pydantic];
    doCheck = false;
  };
in {
  kagi-mcp = mkMcpWrapper {
    name = "kagi-mcp";
    inherit (nv) version;
    pkg = unwrapped;
    modes = {
      stdio = "kagimcp";
      http = "kagimcp --http";
    };
  };
}
