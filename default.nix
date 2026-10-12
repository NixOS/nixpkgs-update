{
  system ? builtins.currentSystem,
  pkgs ? import <nixpkgs> {
    inherit system;
    config = { };
    overlays = [ ];
  },

  mmdoc ? null,
  runtimePkgs ? null,

  inNixShell ? false,
}:
let
  nixpkgs-update = pkgs.callPackage ./pkgs (
    pkgs.lib.filterAttrs (_: v: v != null) {
      inherit mmdoc runtimePkgs;
    }
  );
in
if inNixShell then nixpkgs-update.devShell else nixpkgs-update
