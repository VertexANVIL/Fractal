{ config, lib, ... }: let
    inherit (lib) kube mkIf;
    cfg = config.components.crds;
in {
    options.components.crds = with lib; {
        enable = mkOption {
            type = types.bool;
            default = true;
            description = "Enable CRDs";
        };
    };

    config = mkIf cfg.enable {
        resources = kube.buildKustomization ./.;
    };
}
