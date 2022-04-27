{ inputs, ... }: let
    inherit (inputs) self;
    base = inputs.xnlib.lib;
in base.extend (lib: super: let
    inherit (builtins) toJSON fromJSON toPath readFile readDir replaceStrings pathExists;
    inherit (lib) attrByPath attrNames optional flatten flip head elem length filterAttrs mapAttrs mapAttrs' listToAttrs nameValuePair fold filter last drop
        recursiveMerge splitString concatStringsSep recImportDirs mkProfileAttrs evalModules;

    # todo: hack? should xnlib pass this itself?
    pkgs = import inputs.xnlib.inputs.nixpkgs {
        system = "x86_64-linux";
    };
in super // {
    kube = rec {
        friendlyPathName = path: let
            f = last (splitString "/" path);
        in concatStringsSep "-" (drop 1 (splitString "-" f));

        componentDefaultFile = dir: let
            allowed = ["main.jsonnet" "kustomization.yaml"];
            files = attrNames (filterAttrs (n: v: v == "regular") (readDir dir));
            results = filter (f: elem f allowed) files;
        in if length results > 0 then head results else null;

        # Special module importer to support automatic component generation
        # default.nix will *always* take priority over any other file that produces resources!
        # after that, the order is jsonnet -> kustomize
        componentModules = dir: type: let
            substituter = readFile ./substituter.nix;

            folders = attrNames (filterAttrs (n: v: v == "directory") (readDir dir));
            results = if !(pathExists dir) then [] else map (m: let
                path = dir + "/${m}";
                default = path + "/default.nix";
            in if pathExists default then default else let
                file = componentDefaultFile path;
            in if file == null then null else
                # generate the substitute default file
                toPath (pkgs.writeText "substituter.nix"
                    (replaceStrings [
                        "__MODULE_TYPE__"
                        "__MODULE_NAME__"
                        "__MODULE_PATH__"
                        "__MODULE_DEFAULT_FILE__"
                    ] [
                        type m (toString path) file
                    ] substituter))
            ) folders;
        in filter (m: m != null) results;

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
