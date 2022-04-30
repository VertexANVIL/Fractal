{ type, name, file, path }:
{ config, lib, ... }: let
    inherit (lib) kube;
in {
    # This is a special Nix file that gets customised by Fractal's library
    # It's used to provide a default.nix for modules that don't have one
    options = with lib; mkOption {
        type = types.attrs;
        description = "Configuration for the component";
    };

    resources = component: let
        f = path + "/${file}";
    in if file == "main.jsonnet" then
        kube.compileJsonnet f {
            inherit (config) cluster;
            component = cfg;
        }
    else if file == "kustomization.yaml" then
        kube.compileKustomization path
    else throw "Unsupported component file ${file}!";
}
