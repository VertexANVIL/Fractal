{inputs, cell}: let
    inherit (inputs.nixpkgs.lib) optional;
    inherit (builtins) foldl' mapAttrs;
in {
    transformer = config: resource:
        if config.cluster.renderer.mode == "flux"
        # consume the flux tranformer default for CRDs
        then cell.flux.transformer {inherit config;} null null resource
        else resource;

    builder = config: [] ++ (
        optional (config.cluster.renderer.mode == "flux")
          (cell.flux.buildLayerKustomizations config)
    );
}
