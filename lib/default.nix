{ inputs, ... }: let
    base = inputs.xnlib.lib;
in base.extend (lib: super: let
    inherit (builtins) foldl';
    inherit (lib) mapAttrs;
    
    system = "x86_64-linux";

    # todo: hack? should xnlib pass this itself?
    pkgs = import inputs.xnlib.inputs.nixpkgs {
        inherit system;
    };

    f = path: import path {
        inherit inputs lib pkgs system;
    };
in super // {
    kube = rec {
        builders = f ./builders.nix;
        generators = f ./generators.nix;
        utils = f ./utils.nix;
        validators = f ./validators.nix;

        inherit (builders) compileCrds compileJsonnet compileKustomization;
        inherit (generators) makeStdFlake;
        inherit (utils) defaultNamespaces hasAnnotation defaultAnnotation fixupManifests
            resourceId uniqueResources recursiveTraverseResources reduceStoreDir;
        inherit (validators) transformValidateManifests;

        flux = f ./extensions/flux.nix;

        transformer = { config, ... }@all: resource: fn: let
            definitions = {
                flux = flux.transformer;
            };
        in foldl' (r: f: f r) resource (fn (
            mapAttrs (_: v: v all) definitions
        ));
    };
})
