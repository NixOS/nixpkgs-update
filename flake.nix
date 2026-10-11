{
  description = "update nixpkgs automatically";

  inputs.mmdoc.url = "github:ryantm/mmdoc";
  inputs.mmdoc.inputs.nixpkgs.follows = "nixpkgs";

  inputs.treefmt-nix.url = "github:numtide/treefmt-nix";
  inputs.treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

  inputs.runtimeDeps.url = "github:NixOS/nixpkgs/nixos-unstable-small";

  outputs = { self, nixpkgs, mmdoc, treefmt-nix, runtimeDeps }:
    let
      inherit (builtins) mapAttrs;
      inherit (nixpkgs.lib)
        genAttrs
        mapAttrs'
        mkForce
        nameValuePair
        ;

      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      eachSystem = f: genAttrs systems (system: f system nixpkgs.legacyPackages.${system});
      treefmtEval = eachSystem (
        system: pkgs:
        (treefmt-nix.lib.evalModule pkgs {
          build.wrapper = mkForce (
            pkgs.writeShellApplication {
              name = "treefmt";
              runtimeInputs = packageEval.${system}.devShell.nativeBuildInputs;
              inheritPath = false;
              text = ''exec treefmt "$@"'';
            }
          );
        }).config.build
      );
      packageEval = eachSystem (
        system: pkgs:
        import ./. {
          inherit pkgs system;
          mmdoc = pkgs.lib.recursiveUpdate mmdoc.packages.${system}.mmdoc {
            meta.mainProgram = "mmdoc";
          };
          runtimePkgs = runtimeDeps.legacyPackages.${system};
        }
      );
      pickPackagesFor =
        system:
        let
          pkg = packageEval.${system};
        in
        {
          default = pkg;
          nixpkgs-update = pkg;
          inherit (pkg) nixpkgs-update-doc;
        };
    in
    {
      checks.x86_64-linux =
        let
          packages = mapAttrs' (n: nameValuePair "package-${n}") self.packages.x86_64-linux;
          devShells = mapAttrs' (n: nameValuePair "devShell-${n}") self.devShells.x86_64-linux;
        in
        packages // devShells // {
          treefmt = treefmtEval.x86_64-linux.check self;
        };

      formatter = mapAttrs (_: m: m.wrapper) treefmtEval;

      packages.x86_64-linux = pickPackagesFor "x86_64-linux";
      devShells.x86_64-linux.default = packageEval.x86_64-linux.devShell;

      # nix flake check is broken for these when run on x86_64-linux
      # packages.x86_64-darwin = pickPackagesFor "x86_64-darwin";
      # devShells.x86_64-darwin.default = packageEval.x86_64-darwin.devShell;
    };
}
