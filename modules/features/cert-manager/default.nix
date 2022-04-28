{ config, lib, ... }: let
    inherit (lib) kube mkIf;
    cfg = config.features.cert-manager;
in {
    options.features.cert-manager = with lib; {
        enable = mkEnableOption "Cert Manager";

        name = mkOption {
            type = types.str;
            default = "cert-manager";
            description = "The name of the component";
        };

        version = mkOption {
            type = types.str;
            default = "v1.5.4";
            description = "Version of the Helm chart to use";
        };
    };

    config = mkIf cfg.enable {
        # enable creation of the HelmRepository source
        operators.flux-cd.sources.helm.jetstack.enable = true;

        resources.features = kube.compileJsonnet ./main.jsonnet {
            inherit (config) cluster;
            component = cfg;
        };
    };
}
