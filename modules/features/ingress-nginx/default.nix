{ config, lib, ... }: let
    inherit (lib) kube mkIf;
    cfg = config.features.ingress-nginx;
in {
    options.features.ingress-nginx = with lib; {
        enable = mkEnableOption "NGINX Ingress";

        name = mkOption {
            type = types.str;
            default = "ingress-nginx";
            description = "The name of the component";
        };

        version = mkOption {
            type = types.str;
            default = "4.0.9";
            description = "Version of the Helm chart to use";
        };
    };

    config = mkIf cfg.enable {
        # enable creation of the HelmRepository source
        operators.flux-cd.sources.helm.ingress-nginx.enable = true;

        resources.features = kube.compileJsonnet ./main.jsonnet {
            inherit (config) cluster;
            component = cfg;
        };
    };
}
