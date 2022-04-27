{ config, lib, ... }: let
    cfg = config.features.flux-cd;

    inherit (lib) flatten mapAttrs mapAttrs'
        filterAttrs mkIf nameValuePair recursiveMerge nixFilesIn;
    inherit (lib.kube) resourceId;
in {
    imports = [
        ./sources/helm.nix
    ];

    options.features.flux-cd = with lib; {
        sources = {
            helm = mkOption {
                default = {};
                type = types.attrsOf (types.submodule {
                    options = {
                        enable = mkEnableOption "Enable Source";
                        spec = mkOption {
                            type = types.attrs;
                            description = "The resource spec of the Helm source";
                        };
                    };
                });
            };
        };
    };

    config = {
        # generate the outputs
        resources.features = recursiveMerge [
            # Helm sources
            (mapAttrs' (n: v: let
                resource = {
                    inherit (v) spec;
                    apiVersion = "source.toolkit.fluxcd.io/v1beta1";
                    kind = "HelmRepository";
                    metadata.name = n;
                };
            in nameValuePair (resourceId resource) resource)
                (filterAttrs (_: v: v.enable) cfg.sources.helm))
        ];
    };
}
