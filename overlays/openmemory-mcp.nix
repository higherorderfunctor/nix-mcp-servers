_: final: _: let
  nv = final.nv-sources.openmemory-mcp;
  mkMcpWrapper = final.callPackage ./mk-mcp-wrapper.nix {};
  unwrapped = final.buildNpmPackage {
    pname = "openmemory-mcp-unwrapped";
    inherit (nv) version src npmDepsHash;
    sourceRoot = "package";
    postPatch = "cp ${./locks/openmemory-mcp-package-lock.json} package-lock.json";
    dontNpmBuild = true;
    nativeBuildInputs = [final.makeWrapper];
    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/openmemory-mcp $out/bin
      cp -r bin dist node_modules package.json $out/lib/openmemory-mcp/
      makeWrapper ${final.nodejs}/bin/node $out/bin/openmemory-mcp-unwrapped \
        --add-flags "$out/lib/openmemory-mcp/bin/opm.js" \
        --add-flags "mcp"
      runHook postInstall
    '';
  };
in {
  openmemory-mcp = mkMcpWrapper {
    name = "openmemory-mcp";
    inherit (nv) version;
    pkg = unwrapped;
    modes = {
      stdio = "openmemory-mcp-unwrapped";
      http = "${final.mcp-proxy}/bin/mcp-proxy --port \"$MCP_PORT\" -- openmemory-mcp-unwrapped";
    };
  };
}
