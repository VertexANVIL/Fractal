{
    description = "Fractal Kubernetes Framework";
    inputs = rec {
        xnlib.url = "github:ArctarusLimited/xnlib";
        jrender = {
            url = "github:ArctarusLimited/jrender";
            inputs.nixpkgs.follows = "xnlib/nixpkgs";
        };
    };

    outputs = inputs: {
        lib = import ./lib { inherit inputs; };
        
        defaultApp.x86_64-linux = let
            package = let
                pkgs = import (inputs.xnlib.inputs.nixpkgs) {
                    system = "x86_64-linux";
                };
            in with pkgs; buildGoModule rec {
                pname = "fractal";
                version = "1.0.0";
                src = ./app;
                vendorSha256 = "sha256-VW2Kz4YdY8vhRNTsLzlBFl85eMjzlU4KU3/DdbGiFJs=";
            };
        in {
            type = "app";
            program = "${package}/bin/app";
        };
    };
}
