{
    description = "Fractal Kubernetes Framework";
    inputs = rec {
        xnlib.url = "github:ArctarusLimited/xnlib";
        flake-utils.url = "github:numtide/flake-utils";
        jrender = {
            url = "github:ArctarusLimited/jrender";
            inputs.nixpkgs.follows = "xnlib/nixpkgs";
        };
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
                inherit (pkgs) lib buildGoModule;
            in pkgs.buildGoModule rec {
                pname = "fractal";
                version = "1.0.0";
                src = ./app;

                vendorSha256 = "sha256-ICrEXEJNB1z84eb5X5OSf8i36N4iUkA9Sz6gbe0S3Kc=";

                postInstall = ''
                    mv "$out/bin/app" "$out/bin/fractal"
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
        defaultApp = packages.fractal;
    }));
}
