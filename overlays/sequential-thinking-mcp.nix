_: final: _: let
  nv = final.nv-sources.sequential-thinking-mcp;
  mkMcpWrapper = final.callPackage ./mk-mcp-wrapper.nix {};
  unwrapped = final.buildNpmPackage {
    pname = "sequential-thinking-mcp-unwrapped";
    inherit (nv) version src npmDepsHash;
    sourceRoot = "package";
    postPatch = "cp ${./locks/sequential-thinking-mcp-package-lock.json} package-lock.json";
    dontNpmBuild = true;
    nativeBuildInputs = [final.makeWrapper];
    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/sequential-thinking-mcp $out/bin
      cp -r dist node_modules package.json $out/lib/sequential-thinking-mcp/
      makeWrapper ${final.nodejs}/bin/node $out/bin/sequential-thinking-mcp-unwrapped \
        --add-flags "$out/lib/sequential-thinking-mcp/dist/index.js"
      runHook postInstall
    '';
  };
in {
  sequential-thinking-mcp = mkMcpWrapper {
    name = "sequential-thinking-mcp";
    inherit (nv) version;
    pkg = unwrapped;
    modes = {
      stdio = "sequential-thinking-mcp-unwrapped";
      http = "${final.mcp-proxy}/bin/mcp-proxy --port \"$MCP_PORT\" -- sequential-thinking-mcp-unwrapped";
    };
  };
}
