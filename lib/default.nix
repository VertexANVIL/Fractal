{ inputs, ... }: let
    inherit (inputs) self;
    base = inputs.xnlib.lib;
in base.extend (lib: super: let
    inherit (builtins) toJSON fromJSON readFile toFile;
    inherit (lib) attrByPath mapAttrs mapAttrs' listToAttrs nameValuePair fold filter last drop
        recursiveMerge replaceStrings splitString concatStringsSep recImportDirs mkProfileAttrs evalModules;

    # todo: hack? should xnlib pass this itself?
    pkgs = import inputs.xnlib.inputs.nixpkgs {
        system = "x86_64-linux";
    };
in super // {
    kube = rec {
        friendlyPathName = path: let
            f = last (splitString "/" path);
        in concatStringsSep "-" (drop 1 (splitString "-" f));

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

        # import unique resources from a .nix file
        uniqueResourcesFromFile = inputs: file: let
            data = import file inputs;
        in listToAttrs (map (r: nameValuePair (resourceId r) r)) data;

        # import unique resources from multiple .nix files
        uniqueResourcesFromFiles = inputs: files:
            recursiveMerge (map (f: uniqueResourcesFromFile inputs f) files);

        compileManifests = attrs: let
            source = pkgs.writeText "resources.json" (toJSON attrs);
            result = pkgs.runCommand "kube-compile" {
                preferLocalBuild = true;
                allowSubstitutes = false;
            } "${pkgs.yq-go}/bin/yq e -P '.[] | splitDoc' ${source} > $out";
        in readFile result;

        # Compiles Jsonnet code located at the specified path
        compileJsonnet = path: inputs: let
            f = pkgs.writeText "inputs.json" (toJSON inputs);
            result = pkgs.runCommand "jsonnet-build-${friendlyPathName path}" {
                preferLocalBuild = true;
                allowSubstitutes = false;
            } "${pkgs.go-jsonnet}/bin/jsonnet ${path} -J ${./../support/jsonnet} --ext-code-file inputs=${f} -o $out";
        in uniqueResources (fromJSON (readFile result));

        # Builds a Kustomization and returns Kubernetes objects
        buildKustomization = path: let
            result = pkgs.runCommand "kustomize-build-${friendlyPathName path}" {
                preferLocalBuild = true;
                allowSubstitutes = false;
            } "${pkgs.kustomize}/bin/kustomize build ${path} | ${pkgs.yq-go}/bin/yq ea -o=json '[.]' - > $out";
        in listToAttrs (map (r: nameValuePair (resourceId r) r) (fromJSON (readFile result)));
    };
})
