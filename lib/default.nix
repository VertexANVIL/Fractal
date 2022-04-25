{ inputs, ... }: let
    inherit (inputs) self;
    base = inputs.xnlib.lib;
in base.extend (lib: super: let
    inherit (builtins) toJSON fromJSON readFile toFile;
    inherit (lib) attrByPath mapAttrs mapAttrs' listToAttrs nameValuePair fold filter last drop
        replaceStrings splitString concatStringsSep recImportDirs mkProfileAttrs evalModules;

    # todo: hack? should xnlib pass this itself?
    pkgs = import inputs.xnlib.inputs.nixpkgs {
        system = "x86_64-linux";
    };

    friendlyPathName = path: let
        f = last (splitString "/" path);
    in concatStringsSep "-" (drop 1 (splitString "-" f));
in super // {
    kube = rec {
        clusterConfiguration = {
            configuration,
            extraModules ? [],
            extraSpecialArgs ? {}
        }@args: let
            module = evalModules {
                modules = [ configuration ] ++ extraModules ++ self.kube.modules;
                specialArgs = extraSpecialArgs;
            };
        in rec {
            inherit (module) options config;

            # output the compiled manifests
            resources = compileManifests config.resources;
        };

        resourceId = resource: let
            # replace slashes with underscores
            rep = replaceStrings ["/"] ["_"];
            seek = p: rep (attrByPath p "_" resource);

            group = seek ["apiVersion"];
            kind = resource.kind;
            namespace = seek ["metadata" "namespace"];
            name = resource.metadata.name;
        in "${group}/${kind}/${namespace}/${name}";

        # creates unique IDs for Kubernetes resources
        uniqueResources = mapAttrs' (_: v: nameValuePair (resourceId v) v);

        compileManifests = attrs: let
            source = pkgs.writeText "resources.json" (toJSON attrs);
            result = pkgs.runCommand "kube-compile" {}
                "${pkgs.yq-go}/bin/yq e -P '.[] | splitDoc' ${source} > $out";
        in readFile result;

        # Builds a Kustomization and returns Kubernetes objects
        buildKustomization = path: let
            result = pkgs.runCommand "kustomize-build-${friendlyPathName path}" {}
                "${pkgs.kustomize}/bin/kustomize build ${path} | ${pkgs.yq-go}/bin/yq ea -o=json '[.]' - > $out";
        in listToAttrs (map (r: nameValuePair (resourceId r) r) (fromJSON (readFile result)));

        # Creates a builder to build clusters
        clusterBuilder = {
            # component inputs to the build process
            components ? {},
            # profile inputs to the build process
            profiles ? {}
        }@context: rec {
            # Assembles a cluster from cluster configuration
            buildCluster = cluster: {

            };

            # Assembles multiple clusters from cluster configuration
            buildClusters = mapAttrs (n: v: buildCluster v);
        };
    };
})
