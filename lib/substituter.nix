{ lib, config, ... }: let
    inherit (lib) kube mkIf;
    cfg = config.__MODULE_TYPE__.__MODULE_NAME__;
    default = "__MODULE_DEFAULT_FILE__";
in {
    # This is a special Nix file that gets customised by Fractal's library
    # It's used to provide a default.nix for modules that don't have one
    options.__MODULE_TYPE__.__MODULE_NAME__ = with lib; mkOption {
        type = types.attrs;
        default.enable = false;
        description = "Configuration for the component";
    };

    config = mkIf cfg.enable {
        resources = let
            path = __MODULE_PATH__ + "/${default}";
        in if default == "main.jsonnet" then
            kube.compileJsonnet path {
                inherit (config) cluster;
                component = cfg;
            }
        else if default == "kustomization.yaml" then
            kube.buildKustomization __MODULE_PATH__
        else throw "Unsupported component file ${default}!";
    };
}
