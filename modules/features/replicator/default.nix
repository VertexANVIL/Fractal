{ config, lib, ... }: let
    inherit (lib) kube mkIf;
    cfg = config.features.replicator;
in {
    options.features.replicator = with lib; {
        enable = mkEnableOption "Kubernetes Replicator";

        name = mkOption {
            type = types.str;
            default = "kubernetes-replicator";
            description = "The name of the component";
        };

        version = mkOption {
            type = types.str;
            default = "2.7.2";
            description = "Version of the Helm chart to use";
        };
    };

    config = mkIf cfg.enable {
        # enable creation of the HelmRepository source
        operators.flux-cd.sources.helm.mittwald.enable = true;

        resources.features = kube.compileJsonnet ./main.jsonnet {
            inherit (config) cluster;
            component = cfg;
        };
    };
}
