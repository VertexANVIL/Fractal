{ config, lib, ... }: let
    inherit (lib) kube mkIf;
    cfg = config.features.secret-generator;
in {
    options.features.secret-generator = with lib; {
        enable = mkEnableOption "Secret Generator";

        name = mkOption {
            type = types.str;
            default = "kubernetes-secret-generator";
            description = "The name of the component";
        };

        version = mkOption {
            type = types.str;
            default = "3.3.4";
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
