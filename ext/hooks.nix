{inputs, cell}: let
    l = inputs.nixpkgs.lib // builtins;
in {
    transformer = config: {
        type ? "",
        path ? null
    }: resource:
        if config.cluster.renderer.mode == "flux"
        # consume the flux tranformer default for CRDs
        then cell.flux.transformer {inherit config;} (cell.flux.typeToLayer type) path resource
        else resource;

    builder = config: [] ++ (
        l.optional (config.cluster.renderer.mode == "flux")
          (cell.flux.buildLayerKustomizations config)
    );

    componentBuilder = {
        config, type, name, namespace, metadata
    }@args: {} //
        l.optionalAttrs (config.cluster.renderer.mode == "flux")
          (cell.flux.buildComponentKustomization args);
}
