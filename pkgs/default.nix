{
  lib,
  cabal-install,
  ghcid,
  haskell,
  haskellPackages,
  mmdoc,
  ormolu,
  stdenvNoCC,
  treefmt,

  pkgs,
  runtimePkgs ? pkgs,
}:

let
  deps = with runtimePkgs; {
    NIX = nix;
    GIT = git;
    TREE = tree;
    GIST = gist;
    # TODO: are there more coreutils paths that need locking down?
    TIMEOUT = coreutils;
    NIXPKGSREVIEW = nixpkgs-review;
  };

  haskellPackages' = haskellPackages.override {
    overrides = _: haskellPackages: {
      partial-order = haskell.lib.doJailbreak (haskell.lib.markUnbroken haskellPackages.partial-order);
      polysemy-plugin = haskell.lib.dontCheck haskellPackages.polysemy-plugin;
      polysemy = haskell.lib.dontCheck haskellPackages.polysemy;
      http-api-data = haskell.lib.doJailbreak haskellPackages.http-api-data;
      nixpkgs-update = haskell.lib.justStaticExecutables (
        haskell.lib.failOnAllWarnings (
          haskell.lib.disableExecutableProfiling (
            haskell.lib.disableLibraryProfiling (
              haskellPackages.generateOptparseApplicativeCompletions [ "nixpkgs-update" ] (
                (haskellPackages.callPackage ../nixpkgs-update.nix { }).overrideAttrs (prevAttrs: {
                  env = prevAttrs.env or { } // deps;
                  passthru = prevAttrs.passthru or { } // {
                    nixpkgs-update-doc = doc;
                    devShell = shell;
                  };
                })
              )
            )
          )
        )
      );
    };
  };

  shell = haskellPackages'.shellFor {
    nativeBuildInputs = [
      cabal-install
      ghcid
      haskellPackages'.cabal2nix
      ormolu
      treefmt
    ];
    packages = ps: [ ps.nixpkgs-update ];
    shellHook = ''
      ${lib.toShellVars deps}
      export ${toString (builtins.attrNames deps)}
    '';
  };

  doc = stdenvNoCC.mkDerivation {
    name = "nixpkgs-update-doc";
    src = lib.fileset.toSource {
      root = ../.;
      fileset = ../doc;
    };
    phases = [ "mmdocPhase" ];
    mmdocPhase = "${lib.getExe mmdoc} nixpkgs-update $src/doc $out";
  };

in
haskellPackages'.nixpkgs-update
