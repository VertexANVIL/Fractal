{ inputs, lib, pkgs, ... }: let
    inherit (builtins) isPath isString fromJSON readFile readDir;
    inherit (lib) flatten kube pathExists attrValues mapAttrs mapAttrsToList listToAttrs filterAttrs
        recImportDirs recursiveMerge recursiveModuleTraverse hasSuffix removeSuffix nameValuePair attrNames;
    inherit (inputs) self;
in rec {
    # Builds a Fractal flake with the standard directory structure
    makeStdFlake = {
        inputs, # Inputs from the top-level flake
        flakes ? {}, # Flakes to import modules from
        namespace ? null, # Configuration namespace used for modules generated with substituters
    }: let
        childSelf = inputs.self;
        root = childSelf.outPath;
        flakeMerge = f: (flatten (map f (flakes ++ [childSelf])));

        # output of all components used to make clusters
        components = let
            p = root + "/components";
            sub = import ./substituters/component.nix;
            dirsFor = dir: attrNames (filterAttrs (n: v: v == "directory") (readDir dir));
        in if !(pathExists p) then [] else flatten (map (type:
            flatten (map (name: let
                path = p + "/${type}/${name}";
            in if !(pathExists (path + "/default.nix")) then [] else
                sub { inherit type namespace name path; }
            ) (dirsFor (p + "/${type}")))
        ) (dirsFor p));
    in {
        # inherit the defaultApp so we can run from a subflake
        inherit (self) defaultApp;

        kube = {
            # special outputs used only by the Go application
            _app = {
                clusters = mapAttrs (n: v: v.config.cluster) childSelf.kube.clusters;
            };

            # output of all the clusters we can build
            clusters = let
                dir = root + "/clusters";
            in if !(pathExists dir) then {} else recImportDirs {
                inherit dir;
                _import = n: kube.clusterConfiguration {
                    # CRDs defined at the top level by flakes
                    crds = flakeMerge (f: f.kube.crds.deploy);
                    validationCrds = flakeMerge (f: f.kube.crds.validation);
                    configuration = dir + "/${n}";

                    extraModules = flatten (map (f: f.kube.modules) (flakes ++ [childSelf]));
                    extraSpecialArgs = {
                        inherit inputs;
                        self = childSelf;
                    };
                };
            };

            # output of all custom resource definitions defined at the top level
            crds = {
                deploy = let
                    dir = root + "/crds";
                in if !(pathExists dir) then [] else kube.crdImport dir;

                validation = let
                    dir = root + "/crds/validation";
                in if !(pathExists dir) then [] else kube.crdImport dir;
            };

            # output of all modules used to make clusters
            modules = let
                path = root + "/modules";
                ip = f: path: if pathExists path then f path else [];
            in (ip recursiveModuleTraverse path) ++ components;
        };
    };
}
