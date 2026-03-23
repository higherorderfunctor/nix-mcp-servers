{inputs, ...}: let
  inherit (inputs.nixpkgs) lib;
  import' = path: import path {inherit inputs;};
  overlays = [
    ./sources.nix
    ./nixos-mcp.nix
  ];
in
  lib.composeManyExtensions (map import' overlays)
