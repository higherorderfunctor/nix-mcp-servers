{inputs, ...}: let
  inherit (inputs.nixpkgs) lib;
  import' = path: import path {inherit inputs;};
  overlays = [
    ./sources.nix
    ./context7-mcp.nix
    ./effect-mcp.nix
    ./fetch-mcp.nix
    ./git-intel-mcp.nix
    ./git-mcp.nix
    ./nixos-mcp.nix
  ];
in
  lib.composeManyExtensions (map import' overlays)
