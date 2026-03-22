{inputs, ...}: let
  inherit (inputs.nixpkgs) lib;
  import' = path: import path {inherit inputs;};
  overlays = [
    ./sources.nix
  ];
in
  lib.composeManyExtensions (map import' overlays)
