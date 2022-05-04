{ inputs, ... }: let
    base = inputs.xnlib.lib;
in base.extend (lib: super: let
    inherit (builtins) toJSON fromJSON toPath readFile readDir replaceStrings pathExists hasAttr isAttrs isList foldl';
    inherit (lib) kube attrByPath setAttrByPath attrNames optional flatten flip head elem length filterAttrs genAttrs
        mapAttrs mapAttrs' mapAttrsToList listToAttrs nameValuePair fold filter last drop toLower hasSuffix removeSuffix
        recursiveMerge splitString concatStringsSep recImportDirs mkProfileAttrs evalModules;

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

        componentDefaultFile = dir: let
            allowed = ["main.jsonnet" "kustomization.yaml"];
            files = attrNames (filterAttrs (n: v: v == "regular") (readDir dir));
            results = filter (f: elem f allowed) files;
        in if length results > 0 then head results else null;

        # Special module importer to support automatic component generation
        # default.nix will *always* take priority over any other file that produces resources!
        # after that, the order is jsonnet -> kustomize
        componentImport = dir: substituter: let
            folders = attrNames (filterAttrs (n: v: v == "directory") (readDir dir));
            results = if !(pathExists dir) then {} else genAttrs folders (m: let
                path = dir + "/${m}";
                default = path + "/default.nix";
            in if pathExists default then default else let
                file = componentDefaultFile path;
            in if file == null then null else
                substituter {
                    inherit path file;
                    name = m;
                }
            );
        in filterAttrs (_: v: v != null) results;

        # Imports a directory of custom resource definition YAML files
        crdImport = dir: mapAttrsToList (n: _: let
            friendly = removeSuffix ".yaml" n;
        in
            fromJSON (readFile (pkgs.runCommandLocal "yaml-build-crd-${friendly}" {}
                "cat ${dir + "/${n}"} | ${pkgs.yaml2json}/bin/yaml2json > $out"))
        ) ((filterAttrs (n: _: hasSuffix ".yaml" n) (readDir dir)));

        clusterConfiguration = {
            configuration, crds ? [],
            extraModules ? [],
            extraSpecialArgs ? {}
        }@args: let
            module = let
                baseModule = ./../modules/base/default.nix;
                crdsModule = { ... }: { resources.crds = crds; };
            in evalModules {
                modules = [ configuration baseModule crdsModule ] ++ extraModules;
                specialArgs = extraSpecialArgs;
            };
        in rec {
            inherit (module) options config;

            # output the compiled manifests
            manifests = fixupManifests (flatten [
                (defaultGroupAnnotation "prelude" config.resources.crds)
                (defaultGroupAnnotation "features" (defaultNamespaces config.cluster.namespaces.features config.resources.features))
                (defaultGroupAnnotation "operators" (defaultNamespaces config.cluster.namespaces.operators config.resources.operators))
                (defaultGroupAnnotation "services" (defaultNamespaces config.cluster.namespaces.services config.resources.services))
            ]);

            # output the validation results
            validation = kube.validateManifests manifests
                config.cluster.version (crds ++ config.resources.crds);
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
