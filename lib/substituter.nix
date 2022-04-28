{ type, name, file, path }:
{ lib, config, ... }: let
    inherit (lib) kube mkIf;
    cfg = config.${type}.${name};
in {
    # This is a special Nix file that gets customised by Fractal's library
    # It's used to provide a default.nix for modules that don't have one
    options.${type}.${name} = with lib; mkOption {
        type = types.attrs;
        default.enable = false;
        description = "Configuration for the component";
    };

    config = mkIf cfg.enable {
        resources.${type} = let
            f = path + "/${file}";
        in if file == "main.jsonnet" then
            kube.compileJsonnet f {
                inherit (config) cluster;
                component = cfg;
            }
        else if file == "kustomization.yaml" then
            kube.compileKustomization path
        else throw "Unsupported component file ${file}!";
    };
}
