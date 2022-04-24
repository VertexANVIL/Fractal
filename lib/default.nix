{ inputs, ... }: let
    base = inputs.xnlib.lib;
in base.extend (lib: super: let
    inherit (builtins) toJSON fromJSON readFile toFile currentSystem;
    inherit (lib) attrByPath mapAttrs mapAttrs' listToAttrs nameValuePair last drop
        replaceStrings splitString concatStringsSep recImportDirs mkProfileAttrs;

    # todo: hack? should xnlib pass this itself?
    pkgs = import inputs.xnlib.inputs.nixpkgs {
        system = currentSystem;
    };

    friendlyPathName = path: let
        f = last (splitString "/" path);
    in concatStringsSep "-" (drop 1 (splitString "-" f));
in super // {
    kube = rec {
        resourceId = resource: let
            # replace slashes with underscores
            rep = replaceStrings ["/"] ["_"];
            seek = p: rep (attrByPath p "_" resource);

            group = seek ["apiVersion"];
            kind = seek ["kind"];
            namespace = seek ["metadata" "namespace"];
            name = seek ["metadata" "name"];
        in "${group}/${kind}/${namespace}/${name}";

        # creates unique IDs for Kubernetes resources
        uniqueResources = mapAttrs' (k: v: nameValuePair ((resourceId v) v));

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
