{inputs, ...}: let
  inherit (inputs.nixpkgs) lib;
  import' = path: import path {inherit inputs;};
  overlays = [
    ./sources.nix
    ./context7-mcp.nix
    ./effect-mcp.nix
    ./mcp-proxy.nix
    ./nixos-mcp.nix
  ];
in
  lib.composeManyExtensions (map import' overlays)
