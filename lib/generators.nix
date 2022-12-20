{inputs, cell}: let
    packages = inputs.std.harvest inputs.cells [ "app" "packages" ];
    inherit (cell) utils validators builders;

    inherit (inputs.cells.cfg) modules;
    inherit (inputs.cells.ext) hooks;

    inherit (inputs) xnlib;

    l = inputs.nixpkgs.lib // builtins;
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
        in l.evalModules {
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
            filteredCrds = l.filter (r: r.kind == "CustomResourceDefinition") config.resources;
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
           then l.getAttrFromPath [type namespace name] config
           else l.getAttrFromPath [type name] config;

       # peak into the component and extract the configuration interface
       peak = (l.evalModules { modules = [(modules.component component)]; }).config;

       resources = let
           crds = let
               p = path + "/crds";
           in
             if l.pathExists p
             then map (transformer {}) (builder.compileCrds p)
             else [];

           # try jsonnet, then kustomize, then fallback
           imported =
             if l.pathExists (path + "/main.jsonnet")
             then builder.compileJsonnet { inherit config inputs; } { component = cfg; } path
             else if l.pathExists (path + "/kustomization.yaml")
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
               l.pipe resource [
                   (l.recursiveUpdate { metadata = { inherit labels;}; })
                   (l.recursiveUpdate { metadata = { inherit (peak.metadata) annotations labels; }; })
                   (transformer { inherit path type; })
               ]
           ) imported';
       in crds ++ rendered ++ (
         # create a kustomization entry for this component if we're rendering in Flux mode
         l.optional (l.length (crds ++ rendered) > 0)
           (hooks.componentBuilder { inherit config type name namespace metadata; })
       );

    in {
      inherit _file;
      # set the dynamic component options
      options =
          if namespace != null
          then l.setAttrByPath [type namespace name] peak.options
          else l.setAttrByPath [type name] peak.options;

      # render the configuration c/o the toplevel cluster config
      config = l.mkIf cfg.enable (l.mkMerge [
          (peak.config)
          { inherit resources; }
      ]);
    };

    # Builds a Fractal flake with the standard directory structure
    makeStdFlake = {
        inputs, # Inputs from the top-level flake
        flakes ? [], # Flakes to import modules from
        namespace ? null, # Configuration namespace used for modules generated with makeModuleFromComponent
    }: let
        childSelf = inputs.self;
        root = childSelf.outPath;
        flakeMerge = f: (l.flatten (map f (flakes ++ [childSelf])));

        # output of all components used to make clusters
        components = let
            p = root + "/components";
            dirsFor = dir: l.attrNames (l.filterAttrs (n: v: v == "directory") (l.readDir dir));
        in if !(l.pathExists p) then [] else l.flatten (map (type:
            l.flatten (map (name: let
                path = p + "/${type}/${name}";
            in if !(l.pathExists (path + "/default.nix")) then [] else
                makeModuleFromComponent { inherit type namespace name path; }
            ) (dirsFor (p + "/${type}")))
        ) (dirsFor p));
    in {
        # inherit the packages.<system>.[fractal|default] so we can run from a subflake
        inherit packages;

        kube = {
            # special outputs used only by the Go application
            _app = {
                clusters = l.mapAttrs (n: v: v.config.cluster) childSelf.kube.clusters;
            };

            # output of all the clusters we can build
            clusters = let
                dir = root + "/clusters";
            in if !(l.pathExists dir) then {} else xnlib.lib.recImportDirs {
                inherit dir;
                _import = n: clusterConfiguration {
                    # CRDs defined at the top level by flakes
                    crds = flakeMerge (f: f.kube.crds.deploy);
                    validationCrds = flakeMerge (f: f.kube.crds.validation);
                    configuration = dir + "/${n}";

                    extraModules = l.flatten (map (f: f.kube.modules) (flakes ++ [childSelf]));
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
                in if !(l.pathExists dir) then [] else builders.compileCrds dir;

                validation = let
                    dir = root + "/crds/validation";
                in if !(l.pathExists dir) then [] else builders.compileCrds dir;
            };

            # output of all modules used to make clusters
            modules = let
                path = root + "/modules";
                ip = f: path: if l.pathExists path then f path else [];
            in (ip xnlib.lib.recursiveModuleTraverse path) ++ components;

            # helm outputs required to support locking
            helm = {
                charts = l.unique (l.flatten (l.mapAttrsToList (n: v: v.config.helm.charts) childSelf.kube.clusters));
                sources = let
                    path = root + "/helm.json";
                    attrs = if l.pathExists path then l.fromJSON (l.readFile path) else {};
                in xnlib.lib.recursiveMerge ((map (f: f.kube.helm.sources) flakes) ++ [attrs]);
            };
        };
    };
}
