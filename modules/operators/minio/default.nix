{ config, lib, ... }: let
    inherit (lib) kube mkIf;
    cfg = config.operators.minio;
in {
    options.operators.minio = with lib; {
        enable = mkEnableOption "MinIO";

        name = mkOption {
            type = types.str;
            default = "minio-operator";
            description = "The name of the component";
        };

        version = mkOption {
            type = types.str;
            default = "4.3.5";
            description = "Version of the Helm chart to use";
        };
    };

    config = mkIf cfg.enable {
        # enable creation of the HelmRepository source
        operators.flux-cd.sources.helm.minio.enable = true;

        resources.operators = kube.compileJsonnet ./main.jsonnet {
            inherit (config) cluster;
            component = cfg;
        };
    };
}
