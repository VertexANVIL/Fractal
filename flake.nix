{
    description = "Fractal Kubernetes Framework";
    inputs.xnlib.url = "github:ArctarusLimited/xnlib";

    outputs = inputs@{ self, ... }: let
        lib = import ./lib { inherit inputs; };
        inherit (lib) attrValues flatten kube mapAttrs recursiveModuleTraverse;

        outputs = kube.makeStdFlake { inherit inputs; };
    in outputs // {
        inherit lib;
    };
}
