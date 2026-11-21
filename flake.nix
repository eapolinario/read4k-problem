{
  description = "read4k-problem";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor = system: import nixpkgs { inherit system; };
    in {
      devShells = forAllSystems (system:
        let
          pkgs = pkgsFor system;
        in {
          default = pkgs.mkShell {
            packages = [
              pkgs.go
              pkgs.gopls
              pkgs.golangci-lint
              pkgs.gotools
              pkgs.uv
              pkgs.python314
              pkgs.ruff
              pkgs.pyright
              pkgs.ghc
              pkgs.cabal-install
              pkgs.haskell-language-server
              pkgs.haskellPackages.fourmolu
              pkgs.hlint
              pkgs.just
            ];

            shellHook = ''
              export PYTHONPATH="${pkgs.python314}/lib/python3.14"
              echo "Go + Python 3.14 + Haskell dev shell ready"
            '';
          };
        });

      packages = forAllSystems (system:
        let
          pkgs = pkgsFor system;
        in {
          default = pkgs.stdenv.mkDerivation {
            pname = "read4k-problem";
            version = "0.1.0";
            src = ./.;

            installPhase = "mkdir -p $out";
          };
        });
    };
}
