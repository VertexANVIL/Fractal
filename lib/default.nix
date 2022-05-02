{ inputs, ... }: let
    inherit (inputs) self;
    base = inputs.xnlib.lib;
in base.extend (lib: super: let
    inherit (builtins) toJSON fromJSON toPath readFile readDir replaceStrings pathExists hasAttr isAttrs isList;
    inherit (lib) attrByPath setAttrByPath attrNames optional flatten flip head elem length filterAttrs genAttrs
        mapAttrs mapAttrs' mapAttrsToList listToAttrs nameValuePair fold filter last drop toLower
        recursiveMerge splitString concatStringsSep recImportDirs mkProfileAttrs evalModules;

    # todo: hack? should xnlib pass this itself?
    pkgs = import inputs.xnlib.inputs.nixpkgs {
        system = "x86_64-linux";

        # overlays for packages we import
        # let's move this to a different file later
        overlays = [(final: prev: {
            # add group to kubeval before the PR actually gets in
            kubeval = prev.kubeval.overrideAttrs (o: {
                patches = [ ./patches/kubeval-add-group.patch ];
            });

            # override python for openapi2jsonschema
            python39 = prev.python39.override {
                packageOverrides = final: prev: let
                    inherit (prev) buildPythonApplication fetchPypi
                        colorama click jsonref pytest pyyaml;
                in {
                    # build this straight from pypi
                    openapi2jsonschema = buildPythonApplication rec {
                        pname = "openapi2jsonschema";
                        version = "0.9.1";

                        src = fetchPypi {
                            inherit pname version;
                            sha256 = "sha256-Sd9IUbVuxP3RSHipLUjyZt3k2LduQf3+NlZaNcwfOBE=";
                        };

                        checkInputs = [ pytest ];
                        propagatedBuildInputs = [ colorama click jsonref pyyaml ];
                        patches = [ ./patches/openapi2jsonschema-add-group.patch ];

                        postPatch = ''
                            substituteInPlace setup.py \
                                --replace "click>=7.0,<8.0" "click>=7.0"
                        '';
                    };
                };
            };
        })];
    };

    f = path: import path {
        inherit inputs lib pkgs;
    };
in super // {
    kube = rec {
        generators = f ./generators.nix;
        inherit (generators) makeStdFlake;

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

        clusterConfiguration = {
            configuration, crds ? [],
            extraModules ? [],
            extraSpecialArgs ? {}
        }@args: let
            module = let
                crdsModule = { ... }: { resources.crds = crds; };
            in evalModules {
                modules = [ configuration crdsModule ] ++ extraModules ++ self.kube.modules;
                specialArgs = extraSpecialArgs;
            };
        in rec {
            inherit (module) options config;

            # output the compiled manifests
            manifests = flatten [
                (defaultGroupAnnotation "prelude" config.resources.crds)
                (defaultGroupAnnotation "features" (defaultNamespaces config.cluster.namespaces.features config.resources.features))
                (defaultGroupAnnotation "operators" (defaultNamespaces config.cluster.namespaces.operators config.resources.operators))
                (defaultGroupAnnotation "services" (defaultNamespaces config.cluster.namespaces.services config.resources.services))
            ];
        };

        crdsToJsonSchema = crds: listToAttrs (flatten ((map (v: map (version: let
            name = toLower "${v.spec.names.kind}-${v.spec.group}-${version.name}";
        in nameValuePair name version.schema.openAPIV3Schema) v.spec.versions)) crds));

        # Sets default namespaces on a list of resources
        defaultNamespaces = namespace: list: map (v: if
            ((attrByPath ["metadata" "namespace"] null v) != null)
        then v else v // { metadata = v.metadata // { inherit namespace; }; }) list;

        # Sets group annotation "fractal.k8s.arctarus.net/apply-phase" on a list of resources
        defaultGroupAnnotation = group: list: map (v: let
            path = ["metadata" "annotations" "fractal.k8s.arctarus.net/apply-phase"];
        in if ((attrByPath path null v) != null) then v else recursiveMerge [v (setAttrByPath path group)]) list;

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

        compileManifests = attrs: let
            source = pkgs.writeText "resources.json" (toJSON attrs);
            result = pkgs.runCommandLocal "kube-compile" {}
                "${pkgs.yq-go}/bin/yq e -P '.[] | splitDoc' ${source} > $out";
        in result;

        # Fetches and converts a Kubernetes API schema
        convertSchema = source: let
            fetched = source.fetcher pkgs;
            compiled = pkgs.runCommandLocal "kube-schema-compile" {} ''
                output="$out/v${source.version}-standalone-strict"
                mkdir -p $output && ${pkgs.python39Packages.openapi2jsonschema}/bin/openapi2jsonschema --output $output --kubernetes --strict ${fetched}
            '';
        in {
            inherit (source) version;
            path = compiled;
        };

        validateManifests = attrs: schema: let
            compiled = compileManifests attrs;
        in pkgs.runCommandLocal "kube-check" {} ''
            ln -s ${compiled} resources.yaml
            ln -s ${schema.path} schema
            ${pkgs.kubeval}/bin/kubeval --strict \
                --schema-location file://$(pwd)/schema \
                --kubernetes-version ${schema.version} resources.yaml && touch $out
        '';

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
