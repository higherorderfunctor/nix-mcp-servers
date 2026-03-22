_: final: _: let
  nv = final.nv-sources.git-intel-mcp;
  mkMcpWrapper = final.callPackage ./mk-mcp-wrapper.nix {};
  unwrapped = final.buildNpmPackage {
    pname = "git-intel-mcp-unwrapped";
    inherit (nv) version src npmDepsHash;
    postPatch = "cp ${./locks/git-intel-mcp-package-lock.json} package-lock.json";
    nativeBuildInputs = [final.makeWrapper];
    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/git-intel-mcp $out/bin
      cp -r dist node_modules package.json $out/lib/git-intel-mcp/
      makeWrapper ${final.nodejs}/bin/node $out/bin/git-intel-mcp-unwrapped \
        --add-flags "$out/lib/git-intel-mcp/dist/index.js"
      runHook postInstall
    '';
  };
in {
  # local scope — no --http
  git-intel-mcp = mkMcpWrapper {
    name = "git-intel-mcp";
    inherit (nv) version;
    pkg = unwrapped;
    modes.stdio = "git-intel-mcp-unwrapped";
  };
}
