{inputs, cell}: let
    inherit (inputs.nixpkgs.lib) attrByPath concatStringsSep elemAt foldl'
        imap0 optionalAttrs recursiveUpdate substring;
    inherit (inputs.cells.lib) utils;
in rec {
    transformer = { config, ... }@all:
        layer: path: res: if config.cluster.renderer.mode == "flux" && !(
            # neither annotation can already be set for the transformation to take place
        utils.hasAnnotation res "fractal.k8s.arctarus.net/flux-layer"
            || utils.hasAnnotation res "fractal.k8s.arctarus.net/flux-path") then
        foldl' (r: f: f r) res (if res.kind == "CustomResourceDefinition" then [
            # CRDs always default to deploying inside the prelude
            (i: utils.defaultAnnotation i "fractal.k8s.arctarus.net/flux-path" "layers/10-prelude")
        ] else [
            (i: if layer != null then utils.defaultAnnotation i "fractal.k8s.arctarus.net/flux-layer" layer else i)
            (i: if path != null then utils.defaultAnnotation i "fractal.k8s.arctarus.net/flux-path" (concatStringsSep "/" path) else i)
        ])
    else res;

    # Converts a Fractal type identifier (operators, features, services)
    # to a Flux layer with a numeric order identifier
    typeToLayer = type: let
        mapper = {
            operators = "20-operators";
            features = "30-features";
            services = "40-services";
        };
    in attrByPath [type] (throw "Type ${type} has no default Flux layer!") mapper;

    # Builds a Kustomization for a component
    buildComponentKustomization = {
        config, type, name, namespace, metadata
    }: let
        inherit (config) cluster;
        sourceRef = cluster.renderer.flux.source;
        shortType = substring 0 1 type;
    in {
        apiVersion = "kustomize.toolkit.fluxcd.io/v1beta1";
        kind = "Kustomization";
        metadata = {
            name = "fractal-c-${shortType}-${namespace}-${name}";
            namespace = "flux-system";
            annotations = {
                "fractal.k8s.arctarus.net/flux-path" = "layers/${typeToLayer type}";
            };
        };
        spec = {
            inherit sourceRef;
            interval = "10m0s";
            path = "./${cluster.name}/components/${type}/${namespace}/${name}";
            prune = true;
            #wait = true;
        };
    };

    # Builds the Kustomizations for the Flux layers
    buildLayerKustomizations = config: let
        build = let
            inherit (config) cluster;
            sourceRef = cluster.renderer.flux.source;
        in layer: prev: recursiveUpdate
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
                    inherit sourceRef;
                    interval = "10m0s";
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
        ;

        layers = ["10-prelude" "20-operators" "30-features" "40-services"];
    in imap0 (i: v: let
        prev = if i > 0 then elemAt layers (i - 1) else null;
    in build v prev) layers;
}
