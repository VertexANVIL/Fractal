{inputs, cell}: let
    packages = inputs.std.harvest inputs.cells [ "app" "packages" ];
    inherit (builtins) fromJSON readFile readDir removeAttrs pathExists;
    inherit (inputs.nixpkgs.lib) optional evalModules filter flatten pathExists mapAttrs mapAttrsToList
        filterAttrs unique attrNames hasAttr mkIf mkMerge pipe foldl' attrByPath getAttrFromPath setAttrByPath length recursiveUpdate;
    inherit (inputs.xnlib.lib) recImportDirs recursiveMerge recursiveModuleTraverse;
    inherit (cell) utils validators builders;
    inherit (inputs.cells.cfg) modules;
    inherit (inputs.cells.ext) hooks;
in rec {
    # Builds a cluster configuration
    clusterConfiguration = {
        configuration,
        crds ? [], validationCrds ? [],
        extraModules ? [],
        extraSpecialArgs ? {},
    }@args: let
        module = let
            baseModules = [
                modules.base
                modules.helm
            ];
            crdsModule = { config, ... }: let
                transformer = hooks.transformer config;
            in {
                resources = map (transformer {}) crds;
            };
        in evalModules {
            modules = [ configuration baseModule crdsModule ] ++ extraModules;
            specialArgs = extraSpecialArgs;
        };
    in rec {
        inherit (module) options config;

        # output the compiled manifests
        manifests = let
            fixed = utils.fixupManifests config.resources;
        in fixed ++ (hooks.builder config);

        validatedManifests = let
            filteredCrds = filter (r: r.kind == "CustomResourceDefinition") config.resources;
        in validators.transformValidateManifests manifests
            config.cluster.version (crds ++ validationCrds ++ filteredCrds);
    };

    makeModuleFromComponent = {
      # Type of the component (operators, features, services)
      type,
      # Name of the component
      name,
      # Path to the component's root directory
      path,

      # Namespace of the repository
      namespace ? null
    }: { lib, config, inputs, ... }: let

       _file = (path + "/default.nix");
       component = import _file { inherit lib; };

       transformer = hooks.transformer config;

       # fetch the dynamic component configuration
       cfg =
           if namespace != null
           then getAttrFromPath [type namespace name] config
           else getAttrFromPath [type name] config;

       # peak into the component and extract the configuration interface
       peak = (evalModules { modules = [(modules.component component)]; }).config;

       resources = let
           crds = let
               p = path + "/crds";
           in
             if pathExists p
             then map (transformer {}) (builder.compileCrds p)
             else [];

           # try jsonnet, then kustomize, then fallback
           imported =
             if pathExists (path + "/main.jsonnet")
             then builder.compileJsonnet { inherit config inputs; } { component = cfg; } path
             else if pathExists (path + "/kustomization.yaml")
             then builder.compileKustomization path
             else [];

           imported' = utils.defaultNamespaces config.cluster.namespaces.${type}.name imported;

           rendered = let
               path =
                   if namespace != null
                   then ["components" type namespace name]
                   else ["components" type name]
               ;
               labels = { "fractal.k8s.arctarus.net/component" = "${type}.${namespace}.${name}"; };
           in map (resource:
               pipe resource [
                   (recursiveUpdate { metadata = { inherit labels; }; })
                   (recursiveUpdate { metadata = { inherit (peak.metadata) annotations labels; }; })
                   (transformer { inherit path type; })
               ]
           ) imported';
       in crds ++ rendered ++ (
         # create a kustomization entry for this component if we're rendering in Flux mode
         optional (length (crds ++ rendered) > 0)
           (hooks.componentBuilder { inherit config type name namespace metadata; })
       );

    in {
      inherit _file;
      # set the dynamic component options
      options =
          if namespace != null
          then setAttrByPath [type namespace name] peak.options
          else setAttrByPath [type name] peak.options;

      # render the configuration c/o the toplevel cluster config
      config = mkIf cfg.enable (mkMerge [
          (peak.config)
          { inherit resources; }
      ]);
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
                makeModuleFromComponent { inherit type namespace name path; }
            ) (dirsFor (p + "/${type}")))
        ) (dirsFor p));
    in {
        # inherit the packages.<system>.[fractal|default] so we can run from a subflake
        inherit packages;

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
                in if !(pathExists dir) then [] else builders.compileCrds dir;

                validation = let
                    dir = root + "/crds/validation";
                in if !(pathExists dir) then [] else builders.compileCrds dir;
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
