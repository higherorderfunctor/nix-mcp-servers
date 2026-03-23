_: final: _: let
  nv = final.nv-sources.github-mcp-server;
  mkMcpWrapper = final.callPackage ./mk-mcp-wrapper.nix {};
  unwrapped = final.buildGoModule {
    pname = "github-mcp-unwrapped";
    inherit (nv) version src vendorHash;
    subPackages = ["cmd/github-mcp-server"];
    ldflags = ["-s" "-w" "-X main.version=${nv.version}"];
  };
in {
  github-mcp = mkMcpWrapper {
    name = "github-mcp";
    inherit (nv) version;
    pkg = unwrapped;
    modes = {
      stdio = "github-mcp-server stdio";
      http = "github-mcp-server http";
    };
  };
}
