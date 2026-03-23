_: final: _: let
  nv = final.nv-sources.context7-mcp;
  mkMcpWrapper = final.callPackage ./mk-mcp-wrapper.nix {};
  unwrapped = final.buildNpmPackage {
    pname = "context7-mcp-unwrapped";
    inherit (nv) version src npmDepsHash;
    sourceRoot = "package";
    postPatch = "cp ${./locks/context7-mcp-package-lock.json} package-lock.json";
    dontNpmBuild = true;
    nativeBuildInputs = [final.makeWrapper];
    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/context7-mcp $out/bin
      cp -r dist node_modules package.json $out/lib/context7-mcp/
      makeWrapper ${final.nodejs}/bin/node $out/bin/context7-mcp-unwrapped \
        --add-flags "$out/lib/context7-mcp/dist/index.js"
      runHook postInstall
    '';
  };
in {
  context7-mcp = mkMcpWrapper {
    name = "context7-mcp";
    inherit (nv) version;
    pkg = unwrapped;
    modes = {
      stdio = "context7-mcp-unwrapped --transport stdio";
      http = "context7-mcp-unwrapped --transport http";
    };
  };
}
