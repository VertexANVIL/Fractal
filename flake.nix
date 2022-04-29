{
    description = "Kubernetes Shared Test";
    inputs.xnlib.url = "github:ArctarusLimited/xnlib";

    outputs = inputs@{ self, ... }: let
        lib = import ./lib { inherit inputs; };
        inherit (lib) attrValues flatten kube mapAttrs recursiveModuleTraverse;

        outputs = kube.makeStdFlake { inherit inputs; };
    in outputs // {
        lib = {
            # only need to export the kube part of the library
            inherit (lib) kube;
        };
    };
}
