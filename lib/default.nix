{ inputs, ... }: let
    base = inputs.xnlib.lib;
in base.extend (lib: super: let
    inherit (builtins) toJSON fromJSON toPath readFile readDir replaceStrings pathExists hasAttr isAttrs isList foldl';
    inherit (lib) kube attrByPath setAttrByPath attrNames optional flatten flip head elem length filterAttrs genAttrs
        mapAttrs mapAttrs' mapAttrsToList listToAttrs nameValuePair fold filter last drop toLower hasSuffix removeSuffix
        recursiveMerge splitString concatStringsSep recImportDirs mkProfileAttrs evalModules recursiveUpdate;

    # todo: hack? should xnlib pass this itself?
    pkgs = import inputs.xnlib.inputs.nixpkgs {
        system = "x86_64-linux";
    };

    f = path: import path {
        inherit inputs lib pkgs;
    };
in super // {
    kube = rec {
        generators = f ./generators.nix;
        validators = f ./validators.nix;

        inherit (generators) makeStdFlake;
        inherit (validators) validateManifests;

        # TODO: move the stuff below into their own individual files
        friendlyPathName = path: last (splitString "/" path);

        # Imports a directory of custom resource definition YAML files
        crdImport = dir: mapAttrsToList (n: _: let
            friendly = removeSuffix ".yaml" n;
        in
            fromJSON (readFile (pkgs.runCommandLocal "yaml-build-crd-${friendly}" {}
                "cat ${dir + "/${n}"} | ${pkgs.yaml2json}/bin/yaml2json > $out"))
        ) ((filterAttrs (n: _: hasSuffix ".yaml" n) (readDir dir)));

        clusterConfiguration = {
            configuration,
            crds ? [], validationCrds ? [],
            extraModules ? [],
            extraSpecialArgs ? {},
        }@args: let
            module = let
                baseModule = ./../modules/base/default.nix;
                crdsModule = { ... }: { resources.prelude = crds; };
            in evalModules {
                modules = [ configuration baseModule crdsModule ] ++ extraModules;
                specialArgs = extraSpecialArgs;
            };
        in rec {
            inherit (module) options config;

            # output the compiled manifests
            manifests = fixupManifests (flatten [
                (defaultGroupAnnotation "10-prelude" config.resources.prelude)
                (defaultGroupAnnotation "20-operators" (defaultNamespaces config.cluster.namespaces.operators.name config.resources.operators))
                (defaultGroupAnnotation "30-features" (defaultNamespaces config.cluster.namespaces.features.name config.resources.features))
                (defaultGroupAnnotation "40-services" (defaultNamespaces config.cluster.namespaces.services.name config.resources.services))
            ]);

            # output the validation results
            validation = let
                filtered = filter (r: r.kind == "CustomResourceDefinition") config.resources.prelude;
            in kube.validateManifests manifests
                config.cluster.version (crds ++ validationCrds ++ filtered);
        };

        # Sets default namespaces on a list of resources
        defaultNamespaces = namespace: list: map (v: if
            ((attrByPath ["metadata" "namespace"] null v) != null)
        then v else v // { metadata = v.metadata // { inherit namespace; }; }) list;

        # Sets group annotation "fractal.k8s.arctarus.net/apply-phase" on a list of resources
        defaultGroupAnnotation = group: list: map (v: let
            path = ["metadata" "annotations" "fractal.k8s.arctarus.net/apply-phase"];
        in if ((attrByPath path null v) != null) then v else recursiveMerge [v (setAttrByPath path group)]) list;

        # performs general fixups to resources
        fixupManifests = list: foldl' (
            res: overlay: map overlay res
        ) list [
            # appends our identifier annotation
            (m: recursiveUpdate m {
                metadata = {
                    annotations = {
                        "fractal.k8s.arctarus.net/apply-method" = "flux";
                        "fractal.k8s.arctarus.net/defined" = "true";
                    };
                };
            })

            # removes null creationTimestamp (works around problem with some specific crds)
            (m: m // {
                metadata = filterAttrs (n: v: !(n == "creationTimestamp" && v == null)) m.metadata;
            })
        ];

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
        uniqueResources = list: listToAttrs (map (v: nameValuePair (resourceId v) v) list);

        recursiveTraverseResources = object: let
            isResource = r: (hasAttr "kind" r && hasAttr "metadata" r && hasAttr "name" r.metadata);
        in flatten (if isList object then map recursiveTraverseResources object else
            if isAttrs object then if isResource object then [object] else mapAttrsToList (_: v: recursiveTraverseResources v) object
            else throw "Key does not contain a Kubernetes resource!");

        # Compiles Jsonnet code located at the specified path
        compileJsonnet = path: inputs: let
            f = pkgs.writeText "inputs.json" (toJSON inputs);

            # -J ${dirOf path} is required here because ${path} only brings that specific file into the closure
            result = pkgs.runCommandLocal "jsonnet-build-${friendlyPathName path}" {}
                "${pkgs.go-jsonnet}/bin/jsonnet ${path} -J ${dirOf path} -J ${./../support/jsonnet} --ext-code-file inputs=${f} -o $out";
        in recursiveTraverseResources (fromJSON (readFile result));

        # Builds a Kustomization and returns Kubernetes objects
        compileKustomization = path: let
            result = pkgs.runCommandLocal "kustomize-build-${friendlyPathName path}" {}
                "${pkgs.kustomize}/bin/kustomize build ${path} | ${pkgs.yq-go}/bin/yq ea -o=json '[.]' - > $out";
        in fromJSON (readFile result);
    };
})
