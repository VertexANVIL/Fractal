{ lib, config, ... }: let
    inherit (lib) kube mkIf;
    cfg = config.components.dashboard;
in {
    options.components.dashboard = with lib; {
        enable = mkEnableOption "Kubernetes Dashboard";
    };

    config = mkIf cfg.enable {
        # pass variables through to jsonnet
        # TODO: in the future, we should be able to autogenerate a component
        # based on whether a main.jsonnet file exists and make the configuration attribute set generic

        resources = kube.compileJsonnet ./main.jsonnet {
            inherit (config) cluster;
            component = cfg;
        };
    };
}
