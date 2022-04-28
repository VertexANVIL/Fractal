{ config, lib, ... }: let
    inherit (lib) kube mkIf;
    cfg = config.crds;
in {
    options.crds = with lib; {
        enable = mkOption {
            type = types.bool;
            default = true;
            description = "Enable CRDs";
        };
    };

    config = mkIf cfg.enable {
        resources.crds = kube.compileKustomization ./.;
    };
}
