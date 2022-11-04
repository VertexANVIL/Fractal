{
    description = "Fractal Kubernetes Framework";
    inputs = rec {
        xnlib.url = "github:ArctarusLimited/xnlib";
        flake-utils.url = "github:numtide/flake-utils";
    };

    outputs = { self, nixpkgs, flake-utils, ... }@inputs: let
        inherit (flake-utils.lib) eachDefaultSystem flattenTree;
    in {
        lib = import ./lib { inherit inputs; };
    } // (eachDefaultSystem (system: let
        pkgs = nixpkgs.legacyPackages.${system};
    in rec {
        packages = flattenTree {
            fractal = let
                inherit (pkgs) lib buildGoModule makeWrapper
                    kubernetes-helm kustomize;
            in pkgs.buildGoModule rec {
                pname = "fractal";
                version = "1.0.0";
                src = ./app;

                buildInputs = [ makeWrapper ];
                vendorSha256 = "sha256-BIqJ1PRJjIy/Z7ILr4mA6dE9IqBQabQt/YHgSgajRhw=";

                postInstall = ''
                    mv "$out/bin/app" "$out/bin/fractal"
                '';

                postFixup = let
                    runtimeDeps = [ kubernetes-helm kustomize ];
                in ''
                    wrapProgram "$out/bin/fractal" \
                        --prefix PATH ":" ${lib.makeBinPath runtimeDeps}
                '';

                meta = with lib; {
                    description = "Nix-based framework for building Kubernetes resources";
                    homepage = "https://github.com/ArctarusLimited/Fractal";
                    license = licenses.mit;
                    maintainers = [ maintainers.citadelcore ];
                };
            };
        };

        defaultPackage = packages.fractal;
    }));
}
