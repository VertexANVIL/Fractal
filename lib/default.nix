{ inputs, ... }: let
    inherit (inputs) jrender;
    base = inputs.xnlib.lib;
in base.extend (lib: super: let
    inherit (builtins) toJSON fromJSON toPath readFile readDir replaceStrings pathExists hasAttr isAttrs isList foldl';
    inherit (lib) kube attrByPath setAttrByPath attrNames optional flatten flip head elem length filterAttrs genAttrs elemAt substring unique
        mapAttrs mapAttrs' mapAttrsToList listToAttrs nameValuePair fold filter last drop toLower hasSuffix removeSuffix imap0 optionalAttrs naturalSort
        recursiveMerge splitString concatStringsSep recImportDirs mkProfileAttrs evalModules recursiveUpdate hasPrefix removePrefix;
    
    system = "x86_64-linux";

    # todo: hack? should xnlib pass this itself?
    pkgs = import inputs.xnlib.inputs.nixpkgs {
        inherit system;
    };

    f = path: import path {
        inherit inputs lib pkgs;
    };
in super // {
    kube = rec {
        generators = f ./generators.nix;
        validators = f ./validators.nix;

        inherit (generators) makeStdFlake;
        inherit (validators) transformValidateManifests;

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
                crdsModule = { config, ... }: let
                    tf = transformer { inherit config; };
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
                fixed = fixupManifests config.resources;
                ptfs = flatten [
                    (optional (config.cluster.renderer.mode == "flux") (fluxKustomizations config fixed))
                ];
                all = fixed ++ ptfs;

                filteredCrds = filter (r: r.kind == "CustomResourceDefinition") config.resources;
            in transformValidateManifests all
                config.cluster.version (crds ++ validationCrds ++ filteredCrds);
        };

        # Sets default namespaces on a list of resources
        defaultNamespaces = namespace: list: map (v: if
            ((attrByPath ["metadata" "namespace"] null v) != null)
        then v else v // { metadata = v.metadata // { inherit namespace; }; }) list;

        # Sets the value of an annotation on a resource if it is not already defined
        defaultAnnotation = resource: annotation: value: let
            path = ["metadata" "annotations" annotation];
        in if ((attrByPath path null resource) != null) then resource else recursiveUpdate resource (setAttrByPath path value);

        # performs general fixups to resources
        fixupManifests = list: foldl' (
            res: overlay: map overlay res
        ) list [
            # appends our identifier annotation
            (m: recursiveUpdate m {
                metadata = {
                    # annotations = {
                    #     "fractal.k8s.arctarus.net/apply-method" = "flux";
                    # };

                    labels = {
                        "fractal.k8s.arctarus.net/defined" = "true";
                    };
                };
            })

            # removes null creationTimestamp (works around problem with some specific crds)
            (m: m // {
                metadata = filterAttrs (n: v: !(n == "creationTimestamp" && v == null)) m.metadata;
            })

            # removes namespaces from resources that are not namespaced
            (m: let
                blacklist = [
                    # kubernetes API
                    "ComponentStatus" "Namespace" "Node" "PersistentVolume"
                    "MutatingWebhookConfiguration" "ValidatingWebhookConfiguration" "CustomResourceDefinition"
                    "APIService" "TokenReview" "SelfSubjectAccessReview" "SelfSubjectRulesReview" "SubjectAccessReview"
                    "CertificateSigningRequest" "FlowSchema" "PriorityLevelConfiguration" "NodeMetrics"
                    "IngressClass" "RuntimeClass" "PodSecurityPolicy" "ClusterRoleBinding" "ClusterRole" "PriorityClass"
                    "VolumeSnapshotClass" "VolumeSnapshotContent" "CSIDriver" "CSINode" "StorageClass" "VolumeAttachment"

                    # from CRDs (these should ideally be moved)
                    "CDIConfig" "CDI" "ObjectTransfer" "StorageProfile" "ClusterIssuer"
                    "CiliumClusterwideNetworkPolicy" "CiliumEgressNATPolicy" "CiliumExternalWorkload" "CiliumIdentity" "CiliumNode"
                    "ServerBinding" "ClusterPolicy" "ClusterReportChangeRequest" "Environment" "ServerClass" "Server"
                    "NetworkAddonsConfig" "ClusterPolicyReport"
                ];
            in if (elem m.kind blacklist) then m // {
                metadata = filterAttrs (n: v: n != "namespace") m.metadata;
            } else m)
        ];

        # Generates FluxCD kustomizations based on our custom annotations
        fluxKustomizations = config: manifests: let
            inherit (config) cluster;

            sourceRef = {
                inherit (cluster.renderer.flux.source) kind name namespace;
            };

            interval = "10m0s";

            buildForComponent = layer: path: let
                rep = replaceStrings ["/"] ["-"] path;

                shorthand = let
                    # build the component shorthand
                    # extract out the bits of the path
                    parts = splitString "/" path;
                    type = substring 0 1 (elemAt parts 1);
                    namespace = elemAt parts 2;
                    name = elemAt parts 3;
                in concatStringsSep "-" ["c" type namespace name];
            in {
                apiVersion = "kustomize.toolkit.fluxcd.io/v1beta1";
                kind = "Kustomization";
                metadata = {
                    name = "fractal-${shorthand}";
                    namespace = "flux-system";
                    annotations = {
                        "fractal.k8s.arctarus.net/flux-path" = "layers/${layer}";
                    };
                };
                spec = {
                    inherit sourceRef interval;
                    path = "./${cluster.name}/${path}";
                    prune = false;
                    #wait = true;
                };
            };

            buildForLayer = layer: prev: recursiveMerge [
                {
                    apiVersion = "kustomize.toolkit.fluxcd.io/v1beta1";
                    kind = "Kustomization";
                    metadata = {
                        name = "fractal-l-${layer}";
                        namespace = "flux-system";
                        annotations = {
                            "fractal.k8s.arctarus.net/flux-path" = "cluster";
                        };
                    };
                    spec = {
                        inherit sourceRef interval;
                        path = "./${cluster.name}/layers/${layer}";
                        prune = true;
                        #wait = true;
                    };
                }

                # add dependsOn if prev exists
                (optionalAttrs (prev != null) {
                    spec.dependsOn = [{
                        name = "fractal-l-${prev}";
                    }];
                })
            ];

            layerPath = ["metadata" "annotations" "fractal.k8s.arctarus.net/flux-layer"];
            pathPath = ["metadata" "annotations" "fractal.k8s.arctarus.net/flux-path"];

            bucketManifests = manifests: path: foldl' (
                state: resource: let
                    layer = attrByPath path null resource;
                in if layer != null then recursiveMerge [state (
                    setAttrByPath [layer] [resource]
                )] else state
            ) {} manifests;

            layers = bucketManifests manifests layerPath;
            layerResults = let
                src = let
                    p = mapAttrsToList (n: _: removePrefix "layers/" n)
                        (filterAttrs (n: _: hasPrefix "layers/" n) (bucketManifests manifests pathPath));
                in naturalSort (unique ((attrNames layers) ++ p));
            in imap0 (i: v: let
                prev = if i > 0 then elemAt src (i - 1) else null;
            in buildForLayer v prev) src;

            componentResults = flatten (mapAttrsToList (layer: resources: let
                paths = foldl' (
                    state: resource: let
                        path = attrByPath pathPath null resource;
                    in if path != null then recursiveMerge [state (
                        setAttrByPath [path] [resource]
                    )] else state
                ) {} resources;
            in mapAttrsToList (path: resources:
                if !(hasPrefix "components") path then
                    throw "Resource ${resourceId (head resources)} combines flux-layer with a non-component flux-path ${path}! Only components can be Kustomize-referenced from layers (and use the flux-layer annotation)."
                else buildForComponent layer path
            ) paths) layers);
        in layerResults ++ componentResults;

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

        transformer = { config, ... }: resource: fn: let
            definitions = {
                flux = layer: path: res: if config.cluster.renderer.mode == "flux" then
                    foldl' (r: f: f r) res [
                        (i: if layer != null then defaultAnnotation i "fractal.k8s.arctarus.net/flux-layer" layer else i)
                        (i: if path != null then defaultAnnotation i "fractal.k8s.arctarus.net/flux-path" (concatStringsSep "/" path) else i)
                    ]
                else res;
            };
        in foldl' (r: f: f r) resource (fn definitions);

        typeToFluxLayer = type: let
            mapper = {
                operators = "20-operators";
                features = "30-features";
                services = "40-services";
            };
        in attrByPath [type] (throw "Type ${type} has no default Flux layer!") mapper;

        # Compiles Jsonnet code located at the specified path
        compileJsonnet = path: inputs: let
            f = pkgs.writeText "inputs.json" (toJSON inputs);

            # -J ${dirOf path} is required here because ${path} only brings that specific file into the closure
            result = pkgs.runCommandLocal "jsonnet-build-${friendlyPathName path}" {} ''
                ln -s ${dirOf path} src && cd src
                ${jrender.defaultPackage.${system}}/bin/jrender ${baseNameOf path} -J ${./../support/jsonnet} --ext-code-file inputs=${f} -o $out
            '';
        in recursiveTraverseResources (fromJSON (readFile result));

        # Builds a Kustomization and returns Kubernetes objects
        compileKustomization = path: let
            result = pkgs.runCommandLocal "kustomize-build-${friendlyPathName path}" {}
                "${pkgs.kustomize}/bin/kustomize build ${path} | ${pkgs.yq-go}/bin/yq ea -o=json '[.]' - > $out";
        in fromJSON (readFile result);
    };
})
