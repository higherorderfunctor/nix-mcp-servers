_: final: _: let
  nv = final.nv-sources.effect-mcp;
  mkMcpWrapper = final.callPackage ./mk-mcp-wrapper.nix {};
  unwrapped = final.stdenv.mkDerivation {
    pname = "effect-mcp-unwrapped";
    inherit (nv) version src;
    sourceRoot = ".";
    dontBuild = true;
    nativeBuildInputs = [final.makeWrapper];
    installPhase = ''
      mkdir -p $out/lib/effect-mcp $out/bin
      cp package/main.cjs $out/lib/effect-mcp/
      makeWrapper ${final.nodejs}/bin/node $out/bin/effect-mcp-unwrapped \
        --add-flags "$out/lib/effect-mcp/main.cjs"
    '';
  };
in {
  effect-mcp = mkMcpWrapper {
    name = "effect-mcp";
    inherit (nv) version;
    pkg = unwrapped;
    modes = {
      stdio = "effect-mcp-unwrapped";
      http = "${final.mcp-proxy}/bin/mcp-proxy --port \"$MCP_PORT\" -- effect-mcp-unwrapped";
    };
  };
}
