{ inputs, lib, pkgs, ... }: let
    inherit (builtins) fromJSON readFile readDir;
    inherit (lib) evalModules filter flatten kube optional pathExists mapAttrs mapAttrsToList
        filterAttrs unique recImportDirs recursiveMerge recursiveModuleTraverse attrNames;
    inherit (inputs) self;
in rec {
    # Builds a cluster configuration
    clusterConfiguration = {
        configuration,
        crds ? [], validationCrds ? [],
        extraModules ? [],
        extraSpecialArgs ? {},
    }@args: let
        module = let
            baseModule = ./../modules/base/default.nix;
            crdsModule = { config, ... }: let
                tf = kube.transformer { inherit config; };
            in {
                resources = map (r: tf r (fns: [
                    (fns.flux null ["layers" "10-prelude"])
                ])) crds;
            };
        in evalModules {
            modules = [ configuration baseModule crdsModule ] ++ extraModules;
            specialArgs = extraSpecialArgs;
        };
    in rec {
        inherit (module) options config;

        # output the compiled manifests
        manifests = let
            fixed = kube.fixupManifests config.resources;
            ptfs = flatten [
                (optional (config.cluster.renderer.mode == "flux")
                    (kube.flux.buildLayerKustomizations config))
            ];
        in fixed ++ ptfs;

        validatedManifests = let
            filteredCrds = filter (r: r.kind == "CustomResourceDefinition") config.resources;
        in kube.transformValidateManifests manifests
            config.cluster.version (crds ++ validationCrds ++ filteredCrds);
    };

    # Builds a Fractal flake with the standard directory structure
    makeStdFlake = {
        inputs, # Inputs from the top-level flake
        flakes ? [], # Flakes to import modules from
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
                _import = n: clusterConfiguration {
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
                in if !(pathExists dir) then [] else kube.compileCrds dir;

                validation = let
                    dir = root + "/crds/validation";
                in if !(pathExists dir) then [] else kube.compileCrds dir;
            };

            # output of all modules used to make clusters
            modules = let
                path = root + "/modules";
                ip = f: path: if pathExists path then f path else [];
            in (ip recursiveModuleTraverse path) ++ components;

            # helm outputs required to support locking
            helm = {
                charts = unique (flatten (mapAttrsToList (n: v: v.config.helm.charts) childSelf.kube.clusters));
                sources = let
                    path = root + "/helm.json";
                    attrs = if pathExists path then fromJSON (readFile path) else {};
                in recursiveMerge ((map (f: f.kube.helm.sources) flakes) ++ [attrs]);
            };
        };
    };
}
